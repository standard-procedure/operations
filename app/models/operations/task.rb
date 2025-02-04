module Operations
  class Task < ApplicationRecord
    include StateManagement
    include SubTasks
    include Deletion
    include Testing
    extend InputValidation

    enum :status, in_progress: 0, completed: 1, failed: -1
    serialize :results, coder: Operations::GlobalIDSerialiser, type: Hash, default: {}

    def self.call(data = {})
      validate_inputs! data
      create!(state: initial_state, status_message: "").tap do |task|
        task.send(:process_current_state, DataCarrier.new(data.merge(task: task)))
      end
    end

    def go_to(state, data = {}, message = nil)
      update!(state: state, status_message: (message || state).to_s.truncate(240))
      process_current_state(data)
    end

    def fail_with(message)
      update! status: "failed", status_message: message.to_s.truncate(240), results: {failure_message: message.to_s}
      raise Operations::Failure.new(message, self)
    end

    def complete(results) = update!(status: "completed", status_message: "completed", results: results.to_h)
  end
end
