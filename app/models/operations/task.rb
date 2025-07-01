module Operations
  class Task < ApplicationRecord
    include HasAttributes
    include Plan
    enum :task_status, active: 0, waiting: 10, completed: 100, failed: -1
    serialize :data, coder: JSON, type: Hash, default: {}

    def call(immediate: false)
      while active?
        Rails.logger.debug { "--- #{self}: #{current_state}" }
        (handler_for(current_state).immediate? || immediate) ? handler_for(current_state).call(self) : sleep!
      end
    rescue => ex
      failed!
      raise ex
    end

    def go_to(next_state) = update! current_state: next_state

    def wake_up! = timeout_expired? ? call_timeout_handler : activate_and_call

    private def sleep! = update!(default_times.merge(task_status: "waiting"))

    private def activate_and_call
      active!
      call(immediate: true)
    end

    def self.call(task_status: "active", **attributes) = create!(attributes.merge(task_status: task_status, current_state: initial_state).merge(default_times)).tap { |t| t.call }

    def self.perform_now(**attributes) = call(**attributes)

    def self.perform_later(**attributes) = call(task_status: "waiting", **attributes)
  end
end
