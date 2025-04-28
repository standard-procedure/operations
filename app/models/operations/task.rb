module Operations
  class Task < ApplicationRecord
    include Plan
    include Deletion
    include Testing
    include Exports
    extend InputValidation

    enum :status, in_progress: 0, waiting: 10, completed: 100, failed: -1
    scope :active, -> { where(status: %w[in_progress waiting]) }

    serialize :data, coder: GlobalIdSerialiser, type: Hash, default: {}
    serialize :results, coder: GlobalIdSerialiser, type: Hash, default: {}

    has_many :task_participants, class_name: "Operations::TaskParticipant", dependent: :destroy
    after_save :record_participants

    def to_s = "#{model_name.human}:#{id}"

    def call sub_task_class, **data, &result_handler
      Rails.logger.debug { "#{self}: call #{sub_task_class}" }
      sub_task = sub_task_class.call(**data)
      result_handler&.call(sub_task.results)
      sub_task
    end

    def perform
      return if failed?
      in_progress!
      Rails.logger.debug { "#{self}: performing #{state} with #{data}" }
      handler_for(state).call(self, carrier_for(data))
    rescue => ex
      record_exception(ex)
      raise ex
    end

    class << self
      def call(**data)
        validate_inputs! data
        create!(state: initial_state, status: "in_progress", data: data, status_message: "").tap do |task|
          task.perform
        end
      end
      alias_method :start, :call
    end

    def go_to(state, data = {}, message: nil)
      record_state_transition! state: state, data: data.to_h.except(:task), status_message: (message || state).to_s.truncate(240)
      perform
    end

    def fail_with(message)
      Rails.logger.error { "#{self}: failed #{message}" }
      raise Operations::Failure.new(message, self)
    end

    def complete(results)
      Rails.logger.debug { "#{self}: completed #{results}" }
      update!(status: "completed", status_message: "completed", results: results.to_h)
    end

    protected def record_state_transition! **params
      Rails.logger.debug { "#{self}: state transition to #{state}" }
      params[:data] = params[:data].to_h.except(:task)
      update! params
    end

    private def carrier_for(data) = data.is_a?(DataCarrier) ? data : DataCarrier.new(data.merge(task: self))

    private def record_exception(ex)
      Rails.logger.error { "Exception in #{self} - #{ex.inspect}" }
      update!(status: "failed", status_message: ex.message.to_s.truncate(240), results: {failure_message: ex.message, exception_class: ex.class.name, exception_backtrace: ex.backtrace})
    end

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
  end
end
