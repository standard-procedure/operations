class AddBecomesZombieAtField < ActiveRecord::Migration[8.0]
  def change
    add_column :operations_tasks, :becomes_zombie_at, :datetime, null: true
    add_index :operations_tasks, :becomes_zombie_at
  end
end
