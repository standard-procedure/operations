module Operations
  class Task < ApplicationRecord
    include HasAttributes
    include Plan
    scope :ready_to_wake, -> { ready_to_wake_at(Time.current) }
    scope :ready_to_wake_at, ->(time) { where(wakes_at: ..time) }
    scope :expired, -> { expires_at(Time.current) }
    scope :expired_at, ->(time) { where(expires_at: ..time) }
    scope :ready_to_delete, -> { ready_to_delete_at(Time.current) }
    scope :ready_to_delete_at, ->(time) { where(delete_at: ..time) }

    enum :task_status, active: 0, waiting: 10, completed: 100, failed: -1
    serialize :data, coder: JSON, type: Hash, default: {}
    has_attribute :exception_class, :string
    has_attribute :exception_message, :string
    has_attribute :exception_backtrace, :string

    def call(immediate: false)
      while active?
        Rails.logger.debug { "--- #{self}: #{current_state}" }
        (handler_for(current_state).immediate? || immediate) ? handler_for(current_state).call(self) : sleep!
      end
    rescue => ex
      record_error! ex
      raise ex
    end

    def go_to(next_state) = update! current_state: next_state

    def wake_up! = timeout_expired? ? call_timeout_handler : activate_and_call

    def record_error!(exception) = update!(task_status: "failed", exception_class: exception.class.to_s, exception_message: exception.message.to_s, exception_backtrace: exception.backtrace)

    private def sleep! = update!(default_times.merge(task_status: "waiting"))

    private def activate_and_call
      active!
      call(immediate: true)
    end

    private def call_timeout_handler
      timeout_handler.nil? ? raise(Operations::Timeout.new("Timeout expired", self)) : timeout_handler.call
    rescue => ex
      record_error! ex
      raise ex
    end

    def self.call(task_status: "active", **attributes) = create!(attributes.merge(task_status: task_status, current_state: initial_state).merge(default_times)).tap { |t| t.call }

    def self.later(**attributes) = call(task_status: "waiting", **attributes)

    def self.perform_now(...) = call(...)

    def self.perform_later(...) = later(...)

    def self.wake_sleeping = Task.ready_to_wake.find_each { |t| Operations::WakeTaskJob.perform_later(t) }

    def self.delete_old = Task.ready_to_delete.find_each { |t| Operations::DeleteOldTaskJob.perform_later(t) }
  end
end
