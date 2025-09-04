module Operations
  class Task < ApplicationRecord
    include HasAttributes
    include Plan
    include Index
    include Testing

    scope :active, -> { where(status: %w[active waiting]) }
    scope :ready_to_wake, -> { ready_to_wake_at(Time.current) }
    scope :ready_to_wake_at, ->(time) { waiting.where(wakes_at: ..time) }
    scope :expired, -> { expires_at(Time.current) }
    scope :expired_at, ->(time) { waiting.where(expires_at: ..time) }
    scope :ready_to_delete, -> { ready_to_delete_at(Time.current) }
    scope :ready_to_delete_at, ->(time) { where(delete_at: ..time) }

    # Task hierarchy relationships
    belongs_to :parent, class_name: "Operations::Task", optional: true
    has_many :sub_tasks, class_name: "Operations::Task", foreign_key: "parent_id", dependent: :nullify
    has_many :active_sub_tasks, -> { active }, class_name: "Operations::Task", foreign_key: "parent_id"
    has_many :failed_sub_tasks, -> { failed }, class_name: "Operations::Task", foreign_key: "parent_id"
    has_many :completed_sub_tasks, -> { completed }, class_name: "Operations::Task", foreign_key: "parent_id"

    enum :task_status, active: 0, waiting: 10, completed: 100, failed: -1
    serialize :data, coder: JSON, type: Hash, default: {}
    has_attribute :exception_class, :string
    has_attribute :exception_message, :string
    has_attribute :exception_backtrace, :string

    def call(immediate: false)
      state = ""
      while active? && (state != current_state)
        state = current_state
        Rails.logger.debug { "--- #{self}: #{current_state}" }
        (immediate || state_is_immediate?(current_state)) ? call_handler : go_to_sleep!
      end
    rescue => ex
      record_error! ex
      raise ex
    end

    def go_to(next_state) = update! current_state: next_state, task_status: (state_is_immediate?(next_state) ? "active" : "waiting")

    def wake_up! = timeout_expired? ? call_timeout_handler : activate_and_call

    def start(task_class, **attributes) = task_class.later(**attributes.merge(parent: self))

    def record_error!(exception) = update!(task_status: "failed", exception_class: exception.class.to_s, exception_message: exception.message.to_s, exception_backtrace: exception.backtrace)

    def call_handler = handler_for(current_state).call(self)

    private def state_is_immediate?(state) = handler_for(state).immediate?

    private def go_to_sleep! = update!(default_times.merge(task_status: "waiting"))

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

    class << self
      def call(task_status: "active", **attributes)
        create!(attributes.merge(task_status: task_status, current_state: initial_state).merge(default_times)).tap do |t|
          t.call
        end
      end
      alias_method :perform_now, :call

      def later(**attributes) = call(task_status: "waiting", **attributes)
      alias_method :perform_later, :later

      def wake_sleeping
        adapter = Operations::WakeTaskJob.queue_adapter
        begin
          Task.ready_to_wake.find_each do |task|
            Operations::WakeTaskJob.queue_adapter = task.class.queue_adapter
            Operations::WakeTaskJob.perform_later task
          end
        ensure
          Operations::WakeTaskJob.queue_adapter = adapter
        end
      end

      def delete_old
        Task.ready_to_delete.find_each do |t|
          Operations::DeleteOldTaskJob.perform_later(t)
        end
      end
    end
  end
end
