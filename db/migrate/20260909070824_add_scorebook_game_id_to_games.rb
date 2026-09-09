class AddScorebookGameIdToGames < ActiveRecord::Migration[8.1]
  def change
    add_column :games, :scorebook_game_id, :bigint
  end
end
