require "active_record"

module Operations
  # ActiveRecord model for storing Operations tasks
  class TaskRecord < ::ActiveRecord::Base
    self.table_name = "operations_tasks"

    # Serialize data as JSON
    serialize :data, coder: JSON

    # Scopes for querying
    scope :active, -> { where(status: "active") }
    scope :waiting, -> { where(status: "waiting") }
    scope :completed, -> { where(status: "completed") }
    scope :failed, -> { where(status: "failed") }

    scope :ready_to_wake, -> { ready_to_wake_at(Time.current) }
    scope :ready_to_wake_at, ->(time) { waiting.where("wake_at <= ?", time) }

    scope :expired, -> { expired_at(Time.current) }
    scope :expired_at, ->(time) { waiting.where("timeout_at <= ?", time) }

    scope :ready_to_delete, -> { ready_to_delete_at(Time.current) }
    scope :ready_to_delete_at, ->(time) { where("delete_at <= ?", time) }

    # Task hierarchy
    belongs_to :parent, class_name: "Operations::TaskRecord", optional: true, foreign_key: "parent_task_id"
    has_many :children, class_name: "Operations::TaskRecord", foreign_key: "parent_task_id", dependent: :nullify
  end
end
