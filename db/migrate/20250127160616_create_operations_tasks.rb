class CreateOperationsTasks < ActiveRecord::Migration[8.0]
  def change
    create_table :operations_tasks do |t|
      t.string :type
      t.integer :status, default: 0, null: false
      t.string :state, null: false
      t.string :status_message, default: "", null: false
      t.text :data, default: "{}"
      t.datetime :delete_at, null: false, index: true
      t.timestamps
    end

    add_index :operations_tasks, [:type, :status]
  end
end
