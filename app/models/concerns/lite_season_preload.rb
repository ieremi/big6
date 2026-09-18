# Attaches a Season with only id/year/term loaded (not scorebook_games,
# which can be tens to hundreds of KB of JSONB per season) to each game's
# :season association — for a bulk stats page (Matchup, TeamRecord) that
# touches many distinct seasons at once but only needs year/term/title from
# each, never the full box-score archive.
module LiteSeasonPreload
  module_function

  def attach(games)
    season_ids = games.map(&:season_id).uniq
    seasons_by_id = Season.select(:id, :year, :term).where(id: season_ids).index_by(&:id)
    games.each { |game| game.association(:season).target = seasons_by_id[game.season_id] }
    games
  end
end
