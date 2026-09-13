class AddLeagueOfficialDataToGames < ActiveRecord::Migration[8.1]
  def change
    add_column :games, :league_official_data, :jsonb
  end
end
