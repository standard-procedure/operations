class RenameExistingOperationsTables < ActiveRecord::Migration[8.0]
  def up
    remove_foreign_key :operations_task_participants, :operations_tasks

    rename_table :operations_tasks, :operations_tasks_legacy
    rename_table :operations_task_participants, :operations_task_participants_legacy

    add_foreign_key :operations_task_participants_legacy, :operations_tasks_legacy, column: :task_id
  end

  def down
    remove_foreign_key :operations_task_participants_legacy, :operations_tasks_legacy

    rename_table :operations_tasks_legacy, :operations_tasks
    rename_table :operations_task_participants_legacy, :operations_task_participants

    add_foreign_key :operations_task_participants, :operations_tasks, column: :task_id
  end
end
