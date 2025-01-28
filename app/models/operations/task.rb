module Operations
  class Task < ApplicationRecord
    include StateManagement
    include Deletion
    enum :status, in_progress: 0, completed: 1, failed: -1
    serialize :results, coder: Operations::GlobalIDSerialiser, type: Hash, default: {}

    def self.call(data = {}) = create!(state: initial_state).tap { |task| task.send(:process_current_state, data) }

    def go_to(state, data = {}, message = nil)
      update!(state: state, status_message: message || state.to_s)
      process_current_state(data)
    end

    def complete(**results) = update! status: "completed", results: results
  end
end
