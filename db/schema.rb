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

ActiveRecord::Schema[8.1].define(version: 2026_09_24_000001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "batting_lines", force: :cascade do |t|
    t.integer "ab", default: 0, null: false
    t.integer "caught_stealing", default: 0, null: false
    t.datetime "created_at", null: false
    t.integer "doubles", default: 0, null: false
    t.integer "fielding_errors", default: 0, null: false
    t.bigint "fix_suggestion_id"
    t.bigint "game_id", null: false
    t.integer "gidp", default: 0, null: false
    t.integer "hits", default: 0, null: false
    t.integer "home_runs", default: 0, null: false
    t.integer "pa", default: 0, null: false
    t.bigint "player_id", null: false
    t.string "position"
    t.integer "rbi", default: 0, null: false
    t.integer "runs", default: 0, null: false
    t.integer "sacrifices", default: 0, null: false
    t.integer "stolen_bases", default: 0, null: false
    t.integer "strikeouts", default: 0, null: false
    t.integer "total_bases", default: 0, null: false
    t.integer "triples", default: 0, null: false
    t.bigint "university_id", null: false
    t.datetime "updated_at", null: false
    t.integer "walks", default: 0, null: false
    t.index ["fix_suggestion_id"], name: "index_batting_lines_on_fix_suggestion_id"
    t.index ["game_id", "player_id"], name: "index_batting_lines_on_game_id_and_player_id", unique: true
    t.index ["game_id"], name: "index_batting_lines_on_game_id"
    t.index ["player_id"], name: "index_batting_lines_on_player_id"
    t.index ["university_id"], name: "index_batting_lines_on_university_id"
  end

  create_table "fix_suggestion_lines", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "fix_suggestion_id", null: false
    t.bigint "player_id", null: false
    t.string "position"
    t.bigint "scorebook_line_id", null: false
    t.datetime "updated_at", null: false
    t.jsonb "values", default: {}, null: false
    t.index ["fix_suggestion_id"], name: "index_fix_suggestion_lines_on_fix_suggestion_id"
    t.index ["player_id"], name: "index_fix_suggestion_lines_on_player_id"
    t.index ["scorebook_line_id"], name: "index_fix_suggestion_lines_on_scorebook_line_id", unique: true
  end

  create_table "fix_suggestions", force: :cascade do |t|
    t.datetime "applied_at"
    t.bigint "applied_by_id"
    t.jsonb "candidate_game_ids", default: [], null: false
    t.string "confidence", null: false
    t.datetime "created_at", null: false
    t.datetime "decided_at"
    t.bigint "decided_by_id"
    t.bigint "game_id"
    t.string "key", null: false
    t.string "kind", null: false
    t.text "note"
    t.date "played_on"
    t.bigint "scorebook_game_id"
    t.string "status", default: "pending", null: false
    t.bigint "university_id"
    t.datetime "updated_at", null: false
    t.index ["applied_by_id"], name: "index_fix_suggestions_on_applied_by_id"
    t.index ["decided_by_id"], name: "index_fix_suggestions_on_decided_by_id"
    t.index ["game_id"], name: "index_fix_suggestions_on_game_id"
    t.index ["key"], name: "index_fix_suggestions_on_key", unique: true
    t.index ["status", "played_on"], name: "index_fix_suggestions_on_status_and_played_on"
    t.index ["university_id"], name: "index_fix_suggestions_on_university_id"
  end

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
    t.boolean "counted_in_stats", default: true, null: false
    t.datetime "created_at", null: false
    t.text "data_correction_note"
    t.integer "duration_minutes"
    t.integer "game_number"
    t.integer "game_order"
    t.string "game_status", default: "試合前", null: false
    t.jsonb "league_official_data"
    t.date "played_on", null: false
    t.bigint "scorebook_game_id"
    t.bigint "season_id", null: false
    t.datetime "stats_checked_at"
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

  create_table "identities", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.string "provider", null: false
    t.string "uid", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["provider", "uid"], name: "index_identities_on_provider_and_uid", unique: true
    t.index ["user_id"], name: "index_identities_on_user_id"
  end

  create_table "pitching_lines", force: :cascade do |t|
    t.integer "batters_faced", default: 0, null: false
    t.integer "complete_game", default: 0, null: false
    t.datetime "created_at", null: false
    t.integer "earned_runs", default: 0, null: false
    t.bigint "game_id", null: false
    t.integer "hits", default: 0, null: false
    t.integer "home_runs", default: 0, null: false
    t.integer "losses", default: 0, null: false
    t.integer "outs", default: 0, null: false
    t.integer "pitches", default: 0, null: false
    t.bigint "player_id", null: false
    t.integer "runs", default: 0, null: false
    t.integer "shutout", default: 0, null: false
    t.integer "started", default: 0, null: false
    t.integer "strikeouts", default: 0, null: false
    t.bigint "university_id", null: false
    t.datetime "updated_at", null: false
    t.integer "walks", default: 0, null: false
    t.integer "wins", default: 0, null: false
    t.index ["game_id", "player_id"], name: "index_pitching_lines_on_game_id_and_player_id", unique: true
    t.index ["game_id"], name: "index_pitching_lines_on_game_id"
    t.index ["player_id"], name: "index_pitching_lines_on_player_id"
    t.index ["university_id"], name: "index_pitching_lines_on_university_id"
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

  create_table "scorebook_stats_differences", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "field"
    t.string "key", null: false
    t.string "kind", null: false
    t.boolean "known", default: false, null: false
    t.integer "our_value"
    t.date "played_on"
    t.bigint "player_id", null: false
    t.bigint "scorebook_game_id"
    t.integer "scorebook_value"
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_scorebook_stats_differences_on_key", unique: true
    t.index ["known", "kind"], name: "index_scorebook_stats_differences_on_known_and_kind"
    t.index ["player_id"], name: "index_scorebook_stats_differences_on_player_id"
  end

  create_table "scorebook_stats_player_checks", force: :cascade do |t|
    t.datetime "checked_at", null: false
    t.datetime "created_at", null: false
    t.bigint "player_id", null: false
    t.boolean "readable", default: true, null: false
    t.jsonb "unknown_as_zero", default: {}, null: false
    t.datetime "updated_at", null: false
    t.index ["checked_at"], name: "index_scorebook_stats_player_checks_on_checked_at"
    t.index ["player_id"], name: "index_scorebook_stats_player_checks_on_player_id", unique: true
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

  create_table "users", force: :cascade do |t|
    t.boolean "admin", default: false, null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.datetime "last_signed_in_at"
    t.string "name"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "batting_lines", "fix_suggestions"
  add_foreign_key "batting_lines", "games"
  add_foreign_key "batting_lines", "players"
  add_foreign_key "batting_lines", "universities"
  add_foreign_key "fix_suggestion_lines", "fix_suggestions"
  add_foreign_key "fix_suggestion_lines", "players"
  add_foreign_key "fix_suggestions", "games"
  add_foreign_key "fix_suggestions", "universities"
  add_foreign_key "fix_suggestions", "users", column: "applied_by_id"
  add_foreign_key "fix_suggestions", "users", column: "decided_by_id"
  add_foreign_key "game_members", "games"
  add_foreign_key "game_members", "players"
  add_foreign_key "game_members", "universities"
  add_foreign_key "games", "seasons"
  add_foreign_key "games", "universities", column: "team0_id"
  add_foreign_key "games", "universities", column: "team1_id"
  add_foreign_key "identities", "users"
  add_foreign_key "pitching_lines", "games"
  add_foreign_key "pitching_lines", "players"
  add_foreign_key "pitching_lines", "universities"
  add_foreign_key "players", "universities"
  add_foreign_key "scorebook_stats_differences", "players"
  add_foreign_key "scorebook_stats_player_checks", "players"
end
