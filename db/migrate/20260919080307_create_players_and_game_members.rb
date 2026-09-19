class CreatePlayersAndGameMembers < ActiveRecord::Migration[8.1]
  def change
    # A member of a team's roster (player, manager, coach, ...), as listed in
    # Scorebook's 名鑑. scorebook_id is Scorebook's member id, which is also
    # what its box scores and game rosters reference.
    create_table :players do |t|
      t.bigint :scorebook_id, null: false
      t.references :university, null: false, foreign_key: true
      t.string :name, null: false
      t.string :name_kana
      t.integer :enter_year, null: false
      t.string :role
      t.string :position
      t.string :batting_hand
      t.string :pitching_hand
      t.string :high_school
      t.string :faculty
      t.integer :grade
      t.integer :enrollment_status
      t.timestamps
    end
    add_index :players, :scorebook_id, unique: true
    add_index :players, [ :university_id, :enter_year ]
    add_index :players, :enter_year

    # Who was on a game's roster (bench included) for one team, with the
    # uniform number, grade, and role listed for that game.
    create_table :game_members do |t|
      t.references :game, null: false, foreign_key: true
      t.references :player, null: false, foreign_key: true
      t.references :university, null: false, foreign_key: true
      t.integer :uniform_number
      t.integer :grade
      t.string :role
      t.integer :batting_order
      t.string :fielding_position
      t.timestamps
    end
    add_index :game_members, [ :game_id, :player_id ], unique: true
  end
end
