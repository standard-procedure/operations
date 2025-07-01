class CreateNewOperationsTasks < ActiveRecord::Migration[8.0]
  def change
    create_table :operations_tasks do |t|
      t.belongs_to :parent, foreign_key: {to_table: "operations_tasks"}, null: true
      t.string :type
      t.integer :task_status, default: 0, null: false
      t.string :current_state, default: "start", null: false
      t.text :data
      t.datetime :wakes_at
      t.datetime :expires_at
      t.datetime :completed_at
      t.datetime :failed_at
      t.datetime :delete_at
      t.timestamps

      t.index [:task_status, :wakes_at], name: "operations_task_wakes_at"
      t.index [:task_status, :delete_at], name: "operations_task_delete_at"
    end
  end
end
