class AddGameStatusToGames < ActiveRecord::Migration[8.1]
  def change
    add_column :games, :game_status, :string
  end
end
