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

ActiveRecord::Schema[8.1].define(version: 2026_04_04_005138) do
  create_table "bots", force: :cascade do |t|
    t.boolean "auto_accept_invitations", default: true, null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.text "error_message"
    t.string "name", null: false
    t.string "npub", null: false
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
    t.integer "pattern_type", default: 0, null: false
    t.integer "position"
    t.text "response_text", null: false
    t.datetime "updated_at", null: false
    t.index ["bot_id", "pattern"], name: "index_commands_on_bot_id_and_pattern", unique: true
    t.index ["bot_id"], name: "index_commands_on_bot_id"
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

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "commands", "bots"
  add_foreign_key "sessions", "users"
end
