module Operations
  class Task < ApplicationRecord
    include Plan
    include Deletion
    include Testing
    include Exports
    extend InputValidation

    enum :status, in_progress: 0, completed: 100, failed: -1

    serialize :data, coder: GlobalIdSerialiser, type: Hash, default: {}
    serialize :results, coder: GlobalIdSerialiser, type: Hash, default: {}

    has_many :task_participants, class_name: "Operations::TaskParticipant", dependent: :destroy
    after_save :record_participants

    def call sub_task_class, **data, &result_handler
      sub_task = sub_task_class.call(**data)
      result_handler&.call(sub_task.results)
      sub_task.results
    end

    def perform
      in_progress!
      handler_for(state).call(self, carrier_for(data))
    rescue => ex
      update! status: "failed", status_message: ex.message.to_s.truncate(240), results: {failure_message: ex.message, exception_class: ex.class.name, exception_backtrace: ex.backtrace}
      raise ex
    end

    class << self
      def call(**)
        build(**).tap do |task|
          task.perform
        end
      end
      alias_method :start, :call
    end

    def go_to(state, data = {}, message: nil)
      update!(state: state, data: data.to_h, status_message: (message || state).to_s.truncate(240))
      perform
    end

    def fail_with(message)
      update! status: "failed", status_message: message.to_s.truncate(240), results: {failure_message: message.to_s}
      raise Operations::Failure.new(message, self)
    end

    def complete(results) = update!(status: "completed", status_message: "completed", results: results.to_h)

    private def carrier_for(data) = data.is_a?(DataCarrier) ? data : DataCarrier.new(data.merge(task: self))

    private def record_participants
      record_participants_in :data, data.select { |key, value| value.is_a? Participant }
      record_participants_in :results, results.select { |key, value| value.is_a? Participant }
    end

    private def record_participants_in context, participants
      task_participants.where(context: context).where.not(role: participants.keys).delete_all
      participants.each do |role, participant|
        task_participants.where(context: context, role: role).first_or_initialize.tap do |task_participant|
          task_participant.update! participant: participant
        end
      end
    end

    def self.build(**data)
      validate_inputs! data
      create!(state: initial_state, status: "in_progress", data: data, status_message: "")
    end
  end
end
