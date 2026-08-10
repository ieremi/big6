class CreateGames < ActiveRecord::Migration[8.1]
  def change
    create_table :games do |t|
      t.references :season,
                   null: false,
                   foreign_key: true

      t.references :team0,
                   null: false,
                   foreign_key: { to_table: :universities }

      t.references :team1,
                   null: false,
                   foreign_key: { to_table: :universities }

      t.date :played_on, null: false
      t.integer :game_number, null: false

      t.integer :team0_score
      t.integer :team1_score

      t.timestamps
    end
  end
end