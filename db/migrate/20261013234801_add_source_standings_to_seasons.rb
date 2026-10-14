class AddSourceStandingsToSeasons < ActiveRecord::Migration[8.1]
  def change
    # The standings (勝敗表) of a season whose games come from a printed source
    # such as a club's history (db/sources), as printed there, with the
    # citation: the site has only that club's games of such a season, so the
    # standings can't be worked out from them (SourceGameImport).
    add_column :seasons, :source_standings, :jsonb
  end
end
