module Operations
  class Task < ApplicationRecord
    include StateManagement
    include SubTasks
    include Deletion
    include Testing
    extend InputValidation

    enum :status, in_progress: 0, waiting: 10, completed: 100, failed: -1
    serialize :results, coder: Operations::GlobalIDSerialiser, type: Hash, default: {}

    def perform(data)
      in_progress!
      handler_for(state).call(self, carrier_for(data))
    rescue => ex
      update! status: "failed", status_message: ex.message.to_s.truncate(240), results: {failure_message: ex.message, exception_class: ex.class.name, exception_backtrace: ex.backtrace}
      raise ex
    end

    def perform_later(data)
      waiting!
      TaskRunnerJob.perform_later(self, data: data.to_h)
    end

    def self.call(**data)
      build(background: false, **data).tap do |task|
        task.perform DataCarrier.new(data.merge(task: task))
      end
    end

    def self.start(**data)
      build(background: true, **data).tap do |task|
        task.perform_later data
      end
    end

    def go_to(state, data = {}, message: nil)
      update!(state: state, status_message: (message || state).to_s.truncate(240))
      background? ? perform_later(data) : perform(data)
    end

    def fail_with(message)
      update! status: "failed", status_message: message.to_s.truncate(240), results: {failure_message: message.to_s}
      raise Operations::Failure.new(message, self)
    end

    def complete(results) = update!(status: "completed", status_message: "completed", results: results.to_h)

    private def carrier_for(data) = data.is_a?(DataCarrier) ? data : DataCarrier.new(data.merge(task: self))

    def self.build(background:, **data)
      validate_inputs! data
      create!(state: initial_state, status: background ? "waiting" : "in_progress", status_message: "", background: background)
    end
  end
end
