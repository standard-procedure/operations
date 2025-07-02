class CreateTaskParticipants < ActiveRecord::Migration[8.0]
  def change
    create_table :operations_task_participants do |t|
      t.belongs_to :task, foreign_key: {to_table: "operations_tasks"}
      t.belongs_to :participant, polymorphic: true, index: true
      t.string :attribute_name, default: "", null: false
      t.timestamps
    end
  end
end
