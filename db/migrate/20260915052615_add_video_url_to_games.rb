class AddVideoUrlToGames < ActiveRecord::Migration[8.1]
  def change
    add_column :games, :video_url, :string
  end
end
