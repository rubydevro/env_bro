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

ActiveRecord::Schema[8.1].define(version: 2026_10_29_093306) do
  create_table "env_bro_audit_events", force: :cascade do |t|
    t.string "event", null: false
    t.string "user_label"
    t.string "environment", null: false
    t.json "details", default: {}, null: false
    t.string "proposal_token"
    t.string "file_digest"
    t.integer "proposal_id"
    t.datetime "created_at", null: false
    t.index ["created_at"], name: "index_env_bro_audit_events_on_created_at"
    t.index ["file_digest"], name: "index_env_bro_audit_events_on_file_digest"
    t.index ["proposal_id"], name: "index_env_bro_audit_events_on_proposal_id", unique: true
    t.index ["proposal_token"], name: "index_env_bro_audit_events_on_proposal_token"
  end

  add_foreign_key "env_bro_audit_events", "env_bro_audit_events", column: "proposal_id"
end
