class AgentFields < ActiveRecord::Migration[8.0]
  def change
    add_column :operations_tasks, :wakes_at, :datetime, null: true
    add_column :operations_tasks, :times_out_at, :datetime, null: true
    remove_column :operations_tasks, :background, :boolean, default: false, null: false
    add_index :operations_tasks, :wakes_at
    add_index :operations_tasks, :times_out_at
  end
end
