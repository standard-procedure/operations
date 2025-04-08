class AddTaskParticipantIndexes < ActiveRecord::Migration[8.0]
  def change
    add_index :operations_task_participants, [:participant_type, :participant_id, :created_at, :role, :context]
  end
end
