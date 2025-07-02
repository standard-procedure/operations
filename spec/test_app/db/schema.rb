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

ActiveRecord::Schema[8.0].define(version: 2025_07_01_190716) do
  create_table "documents", force: :cascade do |t|
    t.string "filename", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "operations_tasks", force: :cascade do |t|
    t.integer "parent_id"
    t.string "type"
    t.integer "task_status", default: 0, null: false
    t.string "current_state", default: "start", null: false
    t.text "data"
    t.datetime "wakes_at"
    t.datetime "expires_at"
    t.datetime "completed_at"
    t.datetime "failed_at"
    t.datetime "delete_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_operations_tasks_on_parent_id"
    t.index ["task_status", "delete_at"], name: "operations_task_delete_at"
    t.index ["task_status", "wakes_at"], name: "operations_task_wakes_at"
  end

  create_table "users", force: :cascade do |t|
    t.string "name", null: false
    t.boolean "has_permission", default: false, null: false
    t.boolean "within_download_limits", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "operations_tasks", "operations_tasks", column: "parent_id"
end
