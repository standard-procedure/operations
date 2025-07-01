module Operations
  class Task < ApplicationRecord
    include HasAttributes
    include Plan
    enum :task_status, active: 0, waiting: 10, completed: 100, failed: -1
    serialize :data, coder: JSON, type: Hash, default: {}

    def call
      while active?
        handler_for(current_state).call(self)
      end
    end

    def go_to next_state
      update! current_state: next_state
      Rails.logger.debug { "--- moved to #{current_state}" }
    end

    def self.call **attributes
      create!(attributes.merge(current_state: initial_state)).tap { |t| t.call }
    end

    def self.perform_now(...) = call(...)
  end
end
