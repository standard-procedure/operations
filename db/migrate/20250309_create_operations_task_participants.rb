class CreateOperationsTaskParticipants < ActiveRecord::Migration[7.1]
  def change
    create_table :operations_task_participants do |t|
      t.references :task, null: false, foreign_key: {to_table: :operations_tasks}
      t.references :participant, polymorphic: true, null: false
      t.string :role, null: false
      t.string :context, null: false, default: "data"
      t.timestamps
    end

    add_index :operations_task_participants, [:task_id, :participant_type, :participant_id, :role, :context],
      name: "index_operations_task_participants_on_full_identity",
      unique: true
  end
end
