# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_01_27_161543) do
  create_table "documents", force: :cascade do |t|
    t.string "filename", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "operations_tasks", force: :cascade do |t|
    t.string "type"
    t.integer "status", default: 0, null: false
    t.string "state", null: false
    t.string "status_message", default: "", null: false
    t.text "results", default: "{}"
    t.datetime "delete_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["delete_at"], name: "index_operations_tasks_on_delete_at"
    t.index ["type", "status"], name: "index_operations_tasks_on_type_and_status"
  end

  create_table "users", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end
end
