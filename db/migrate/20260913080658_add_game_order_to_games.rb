class AddGameOrderToGames < ActiveRecord::Migration[8.1]
  def change
    add_column :games, :game_order, :integer
  end
end
