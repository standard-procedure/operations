class CreateOperationsTasks < ActiveRecord::Migration[7.0]
  def change
    create_table :operations_tasks do |t|
      # Task identity
      t.string :task_type, null: false
      t.string :status, null: false, default: "active"
      t.string :current_state, null: false

      # Task data (attributes and models stored as JSON)
      t.json :data, default: {}

      # Task hierarchy
      t.bigint :parent_task_id

      # Error tracking
      t.string :exception_class
      t.text :exception_message
      t.text :exception_backtrace

      # Timing
      t.datetime :wake_at
      t.datetime :timeout_at
      t.datetime :delete_at

      t.timestamps
    end

    add_index :operations_tasks, :task_type
    add_index :operations_tasks, :status
    add_index :operations_tasks, :current_state
    add_index :operations_tasks, :parent_task_id
    add_index :operations_tasks, :wake_at
    add_index :operations_tasks, :timeout_at
    add_index :operations_tasks, :delete_at
    add_index :operations_tasks, [:status, :wake_at]
  end
end
