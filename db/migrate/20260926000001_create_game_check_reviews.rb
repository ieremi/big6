class CreateGameCheckReviews < ActiveRecord::Migration[8.1]
  def change
    # A finding of the games data check (GameDataCheck) an admin has looked at
    # and found to be fine (a real double-header, a playoff, the rules of the
    # day), with why. key is the finding's, which stays the same from check to
    # check, so a reviewed finding is left out of the list from then on.
    create_table :game_check_reviews do |t|
      t.string :key, null: false
      t.text :note
      t.references :reviewed_by, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :game_check_reviews, :key, unique: true
  end
end
