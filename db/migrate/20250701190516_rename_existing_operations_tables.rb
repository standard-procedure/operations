class RenameExistingOperationsTables < ActiveRecord::Migration[8.0]
  def up
    remove_foreign_key :operations_task_participants, :operations_tasks, if_exists: true if table_exists?("operations_task_participants")

    rename_table :operations_tasks, :operations_tasks_legacy if table_exists?("operations_tasks")
    rename_table :operations_task_participants, :operations_task_participants_legacy if table_exists?("operations_task_participants")

    add_foreign_key :operations_task_participants_legacy, :operations_tasks_legacy, column: :task_id if table_exists?("operations_task_participants_legacy")
  end

  def down
    remove_foreign_key :operations_task_participants_legacy, :operations_tasks_legacy if table_exists?("operations_task_participants_legacy")

    rename_table :operations_tasks_legacy, :operations_tasks if table_exists?("operations_task_legacy")
    rename_table :operations_task_participants_legacy, :operations_task_participants if table_exists?("operations_task_participants_legacy")

    add_foreign_key :operations_task_participants, :operations_tasks, column: :task_id if table_exists?("operations_task_participants")
  end
end
