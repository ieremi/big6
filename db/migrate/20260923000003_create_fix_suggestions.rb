class CreateFixSuggestions < ActiveRecord::Migration[8.1]
  def change
    # A fix to our data suggested from what the nightly Scorebook check found
    # (FixSuggestion explains the kinds), for an admin to approve or discard.
    # key identifies what it is about, so the same thing is never suggested
    # twice, even once discarded.
    create_table :fix_suggestions do |t|
      t.string :kind, null: false
      t.string :key, null: false
      t.string :status, null: false, default: "pending"
      t.string :confidence, null: false
      t.references :university, foreign_key: true # whose lines
      t.bigint :scorebook_game_id # the game Scorebook files the lines under
      t.references :game, foreign_key: true # our game they belong to, as guessed
      t.jsonb :candidate_game_ids, null: false, default: []
      t.date :played_on
      t.text :note
      t.datetime :decided_at
      t.references :decided_by, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :fix_suggestions, :key, unique: true
    add_index :fix_suggestions, [ :status, :played_on ]

    # The Scorebook lines a suggestion is about: one player's batting in one
    # game, as Scorebook's member page has it (values keyed as
    # ScorebookMemberStats::FIELDS, nil where not recorded).
    create_table :fix_suggestion_lines do |t|
      t.references :fix_suggestion, null: false, foreign_key: true
      t.references :player, null: false, foreign_key: true
      t.bigint :scorebook_line_id, null: false
      t.string :position
      t.jsonb :values, null: false, default: {}
      t.timestamps
    end
    add_index :fix_suggestion_lines, :scorebook_line_id, unique: true
  end
end
