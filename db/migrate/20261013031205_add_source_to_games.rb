class AddSourceToGames < ActiveRecord::Migration[8.1]
  def change
    # Games that Scorebook doesn't have, taken from a printed source such as a
    # club's history (db/sources): the citation and a link to it, shown on the
    # game page and in the API, and the line score in the shape of Scorebook's
    # own game data ("runs1Top", "stadium", ...), so GameScoreboard shows it as
    # it shows Scorebook's.
    add_column :games, :source_citation, :text
    add_column :games, :source_url, :string
    add_column :games, :source_scoreboard, :jsonb
  end
end
