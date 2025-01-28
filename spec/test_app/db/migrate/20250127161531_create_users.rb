class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :name, null: false
      t.boolean :has_permission, default: false, null: false
      t.boolean :within_download_limits, default: false, null: false
      t.timestamps
    end
  end
end
