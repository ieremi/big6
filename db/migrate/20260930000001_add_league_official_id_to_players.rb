class AddLeagueOfficialIdToPlayers < ActiveRecord::Migration[8.1]
  def change
    # The player's ID on the league's site (big6.gr.jp), e.g. "AK23UT0": the
    # box score links each player to it. Set once LeagueOfficialPlayerLink has
    # matched the player's page to this player, and then used to match the
    # box score's players without guessing (LeagueOfficialLineup).
    add_column :players, :league_official_id, :string
    add_index :players, :league_official_id, unique: true
  end
end
