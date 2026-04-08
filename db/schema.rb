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

ActiveRecord::Schema[8.1].define(version: 2026_04_07_230446) do
  create_table "bots", force: :cascade do |t|
    t.boolean "auto_accept_invitations", default: true, null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.text "error_message"
    t.string "name", null: false
    t.string "npub", null: false
    t.string "picture_url"
    t.text "script_data", default: "{}", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["npub"], name: "index_bots_on_npub", unique: true
  end

  create_table "commands", force: :cascade do |t|
    t.integer "bot_id", null: false
    t.datetime "created_at", null: false
    t.boolean "enabled", default: true, null: false
    t.string "name", null: false
    t.string "pattern", null: false
    t.text "response_text", null: false
    t.integer "response_type", default: 3, null: false
    t.datetime "updated_at", null: false
    t.index ["bot_id", "pattern"], name: "index_commands_on_bot_id_and_pattern", unique: true
    t.index ["bot_id"], name: "index_commands_on_bot_id"
  end

  create_table "message_logs", force: :cascade do |t|
    t.string "author", null: false
    t.integer "bot_id", null: false
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.string "direction", null: false
    t.string "group_id", null: false
    t.datetime "message_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bot_id", "group_id"], name: "index_message_logs_on_bot_id_and_group_id"
    t.index ["bot_id", "message_at"], name: "index_message_logs_on_bot_id_and_message_at"
    t.index ["bot_id"], name: "index_message_logs_on_bot_id"
  end

  create_table "scheduled_actions", force: :cascade do |t|
    t.text "action_config", null: false
    t.integer "action_type", default: 0, null: false
    t.integer "bot_id", null: false
    t.datetime "created_at", null: false
    t.boolean "enabled", default: true, null: false
    t.datetime "last_run_at"
    t.string "name", null: false
    t.datetime "next_run_at"
    t.string "schedule", null: false
    t.text "script_body"
    t.datetime "updated_at", null: false
    t.index ["bot_id"], name: "index_scheduled_actions_on_bot_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "settings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.text "value"
    t.index ["key"], name: "index_settings_on_key", unique: true
  end

  create_table "triggers", force: :cascade do |t|
    t.text "action_config"
    t.integer "action_type", default: 0, null: false
    t.integer "bot_id", null: false
    t.integer "condition_type", default: 0, null: false
    t.string "condition_value"
    t.datetime "created_at", null: false
    t.boolean "enabled", default: true, null: false
    t.integer "event_type", default: 0, null: false
    t.string "name", null: false
    t.integer "position"
    t.text "script_body"
    t.datetime "updated_at", null: false
    t.index ["bot_id"], name: "index_triggers_on_bot_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "commands", "bots"
  add_foreign_key "message_logs", "bots"
  add_foreign_key "scheduled_actions", "bots"
  add_foreign_key "sessions", "users"
  add_foreign_key "triggers", "bots"
end
