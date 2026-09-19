class CreateBattingAndPitchingLines < ActiveRecord::Migration[8.1]
  def change
    # One row per batter per game, from Scorebook's box score. Season and
    # career totals are summed from these.
    create_table :batting_lines do |t|
      t.references :game, null: false, foreign_key: true
      t.references :player, null: false, foreign_key: true
      t.references :university, null: false, foreign_key: true
      t.string :position
      t.integer :pa, null: false, default: 0
      t.integer :ab, null: false, default: 0
      t.integer :runs, null: false, default: 0
      t.integer :hits, null: false, default: 0
      t.integer :doubles, null: false, default: 0
      t.integer :triples, null: false, default: 0
      t.integer :home_runs, null: false, default: 0
      t.integer :total_bases, null: false, default: 0
      t.integer :rbi, null: false, default: 0
      t.integer :strikeouts, null: false, default: 0
      t.integer :walks, null: false, default: 0 # 四死球
      t.integer :sacrifices, null: false, default: 0 # 犠打・犠飛
      t.integer :stolen_bases, null: false, default: 0
      t.integer :caught_stealing, null: false, default: 0
      t.integer :gidp, null: false, default: 0
      t.integer :fielding_errors, null: false, default: 0
      t.timestamps
    end
    add_index :batting_lines, [ :game_id, :player_id ], unique: true

    # One row per pitcher per game. Innings are stored as outs (3 per inning)
    # so partial innings sum exactly.
    create_table :pitching_lines do |t|
      t.references :game, null: false, foreign_key: true
      t.references :player, null: false, foreign_key: true
      t.references :university, null: false, foreign_key: true
      t.integer :batters_faced, null: false, default: 0
      t.integer :outs, null: false, default: 0
      t.integer :hits, null: false, default: 0
      t.integer :home_runs, null: false, default: 0
      t.integer :walks, null: false, default: 0 # 与四死球
      t.integer :strikeouts, null: false, default: 0
      t.integer :runs, null: false, default: 0
      t.integer :earned_runs, null: false, default: 0
      t.integer :pitches, null: false, default: 0
      t.integer :started, null: false, default: 0
      t.integer :complete_game, null: false, default: 0
      t.integer :shutout, null: false, default: 0
      t.integer :wins, null: false, default: 0
      t.integer :losses, null: false, default: 0
      t.timestamps
    end
    add_index :pitching_lines, [ :game_id, :player_id ], unique: true

    # When this game's box score was last fetched from Scorebook, whether or
    # not it had player stats, so a backfill can skip games it already tried.
    add_column :games, :stats_checked_at, :datetime
  end
end
