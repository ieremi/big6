class AddWeatherToGames < ActiveRecord::Migration[8.1]
  def change
    add_column :games, :weather_summary, :string
    add_column :games, :temp_high, :float
    add_column :games, :temp_low, :float
  end
end
