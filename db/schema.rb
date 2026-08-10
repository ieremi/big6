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

ActiveRecord::Schema[8.1].define(version: 2026_08_10_042952) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "games", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "game_number", null: false
    t.date "played_on", null: false
    t.bigint "season_id", null: false
    t.bigint "team0_id", null: false
    t.integer "team0_score"
    t.bigint "team1_id", null: false
    t.integer "team1_score"
    t.datetime "updated_at", null: false
    t.index ["season_id"], name: "index_games_on_season_id"
    t.index ["team0_id"], name: "index_games_on_team0_id"
    t.index ["team1_id"], name: "index_games_on_team1_id"
  end

  create_table "seasons", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "term"
    t.datetime "updated_at", null: false
    t.integer "year"
  end

  create_table "universities", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.string "short_name"
    t.string "slug"
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_universities_on_slug", unique: true
  end

  add_foreign_key "games", "seasons"
  add_foreign_key "games", "universities", column: "team0_id"
  add_foreign_key "games", "universities", column: "team1_id"
end
