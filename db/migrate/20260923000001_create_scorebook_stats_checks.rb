class CreateScorebookStatsChecks < ActiveRecord::Migration[8.1]
  def change
    # When each player's batting lines were last checked against Scorebook's
    # member page (ScorebookStatsCheck), and what that check found besides
    # differences: whether the page could be read, and how many values
    # Scorebook didn't record are 0 here, by column.
    create_table :scorebook_stats_player_checks do |t|
      t.references :player, null: false, foreign_key: true, index: { unique: true }
      t.datetime :checked_at, null: false
      t.boolean :readable, null: false, default: true
      t.jsonb :unknown_as_zero, null: false, default: {}
      t.timestamps
    end
    add_index :scorebook_stats_player_checks, :checked_at

    # The differences the latest check of each player found, one row per
    # difference, keyed as ScorebookStatsCheck::Difference#key. A row stays
    # while later checks find it again (created_at is when it was first
    # found) and goes once one doesn't. known marks one that has been looked
    # at, so only the others are reported as new.
    create_table :scorebook_stats_differences do |t|
      t.references :player, null: false, foreign_key: true
      t.string :key, null: false
      t.string :kind, null: false
      t.bigint :scorebook_game_id
      t.date :played_on
      t.string :field
      t.integer :scorebook_value
      t.integer :our_value
      t.boolean :known, null: false, default: false
      t.timestamps
    end
    add_index :scorebook_stats_differences, :key, unique: true
    add_index :scorebook_stats_differences, [ :known, :kind ]
  end
end
