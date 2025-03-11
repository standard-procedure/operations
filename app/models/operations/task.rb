module Operations
  class Task < ApplicationRecord
    include StateManagement
    include Deletion
    include Testing
    include Background
    include Exports
    extend InputValidation

    enum :status, in_progress: 0, waiting: 10, completed: 100, failed: -1

    serialize :data, coder: GlobalIdSerialiser, type: Hash, default: {}
    serialize :results, coder: GlobalIdSerialiser, type: Hash, default: {}

    has_many :task_participants, class_name: "Operations::TaskParticipant", dependent: :destroy
    after_save :record_participants

    def call sub_task_class, **data, &result_handler
      sub_task = sub_task_class.call(**data)
      result_handler&.call(sub_task.results)
      sub_task.results
    end

    def start sub_task_class, **data, &result_handler
      sub_task_class.start(**data)
    end

    def perform
      timeout!
      in_progress!
      handler_for(state).call(self, carrier_for(data))
    rescue => ex
      update! status: "failed", status_message: ex.message.to_s.truncate(240), results: {failure_message: ex.message, exception_class: ex.class.name, exception_backtrace: ex.backtrace}
      raise ex
    end

    def perform_later
      waiting!
      TaskRunnerJob.set(wait_until: background_delay.from_now).perform_later self
    end

    def self.call(**)
      build(background: false, **).tap do |task|
        task.perform
      end
    end

    def self.start(**data)
      build(background: true, **with_timeout(data)).tap do |task|
        task.perform_later
      end
    end

    def go_to(state, data = {}, message: nil)
      update!(state: state, data: data.to_h, status_message: (message || state).to_s.truncate(240))
      background? ? perform_later : perform
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

    def self.build(background:, **data)
      validate_inputs! data
      create!(state: initial_state, status: background ? "waiting" : "in_progress", data: data, status_message: "", background: background)
    end
  end
end
