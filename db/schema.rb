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

ActiveRecord::Schema[8.1].define(version: 2026_09_19_082226) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "game_members", force: :cascade do |t|
    t.integer "batting_order"
    t.datetime "created_at", null: false
    t.string "fielding_position"
    t.bigint "game_id", null: false
    t.integer "grade"
    t.bigint "player_id", null: false
    t.string "role"
    t.integer "uniform_number"
    t.bigint "university_id", null: false
    t.datetime "updated_at", null: false
    t.index ["game_id", "player_id"], name: "index_game_members_on_game_id_and_player_id", unique: true
    t.index ["game_id"], name: "index_game_members_on_game_id"
    t.index ["player_id"], name: "index_game_members_on_player_id"
    t.index ["university_id"], name: "index_game_members_on_university_id"
  end

  create_table "games", force: :cascade do |t|
    t.integer "attendance"
    t.datetime "created_at", null: false
    t.text "data_correction_note"
    t.integer "duration_minutes"
    t.integer "game_number", null: false
    t.integer "game_order"
    t.string "game_status"
    t.jsonb "league_official_data"
    t.date "played_on", null: false
    t.bigint "scorebook_game_id"
    t.bigint "season_id", null: false
    t.bigint "team0_id", null: false
    t.integer "team0_score"
    t.bigint "team1_id", null: false
    t.integer "team1_score"
    t.float "temp_high"
    t.float "temp_low"
    t.datetime "updated_at", null: false
    t.string "video_url"
    t.string "weather_summary"
    t.index ["season_id"], name: "index_games_on_season_id"
    t.index ["team0_id"], name: "index_games_on_team0_id"
    t.index ["team1_id"], name: "index_games_on_team1_id"
  end

  create_table "gdp_per_capita_years", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "usd", null: false
    t.integer "year", null: false
    t.index ["year"], name: "index_gdp_per_capita_years_on_year", unique: true
  end

  create_table "players", force: :cascade do |t|
    t.string "batting_hand"
    t.datetime "created_at", null: false
    t.integer "enrollment_status"
    t.integer "enter_year"
    t.string "faculty"
    t.integer "grade"
    t.string "high_school"
    t.string "name", null: false
    t.string "name_kana"
    t.string "pitching_hand"
    t.string "position"
    t.string "role"
    t.bigint "scorebook_id", null: false
    t.bigint "university_id", null: false
    t.datetime "updated_at", null: false
    t.index ["enter_year"], name: "index_players_on_enter_year"
    t.index ["scorebook_id"], name: "index_players_on_scorebook_id", unique: true
    t.index ["university_id", "enter_year"], name: "index_players_on_university_id_and_enter_year"
    t.index ["university_id"], name: "index_players_on_university_id"
  end

  create_table "prime_minister_terms", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "end_on"
    t.string "name", null: false
    t.date "start_on", null: false
    t.datetime "updated_at", null: false
    t.index ["start_on"], name: "index_prime_minister_terms_on_start_on"
  end

  create_table "seasons", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "scorebook_data"
    t.jsonb "scorebook_games"
    t.string "term"
    t.datetime "updated_at", null: false
    t.integer "year"
  end

  create_table "universities", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.integer "position", null: false
    t.string "short_name"
    t.string "slug"
    t.datetime "updated_at", null: false
    t.index ["position"], name: "index_universities_on_position", unique: true
    t.index ["slug"], name: "index_universities_on_slug", unique: true
  end

  add_foreign_key "game_members", "games"
  add_foreign_key "game_members", "players"
  add_foreign_key "game_members", "universities"
  add_foreign_key "games", "seasons"
  add_foreign_key "games", "universities", column: "team0_id"
  add_foreign_key "games", "universities", column: "team1_id"
  add_foreign_key "players", "universities"
end
