# One-off backfill: populates Game#duration_minutes (added so Matchup/
# TeamRecord's period stats don't need to load each game's full season
# JSONB via GameScoreboard just to read a duration) from each season's
# already-stored scorebook_games — no HTTP calls, just re-parsing data
# already in the database.
#
# game.rb/scorebook_sync.rb now populate this at import time, so this is
# only needed once for games imported before that.
#
# Run with: bin/rails runner script/big6/backfill_duration_minutes.rb

updated = 0

Season.where.not(scorebook_games: nil).find_each do |season|
  games_by_scorebook_id = Game.where(season: season).where.not(scorebook_game_id: nil).index_by(&:scorebook_game_id)

  season.scorebook_games.each do |info|
    game = games_by_scorebook_id[info["id"]]
    next unless game

    minutes = GameScoreboard.parse_duration_minutes(info["gameTimeNet"])
    next if game.duration_minutes == minutes

    game.update_column(:duration_minutes, minutes)
    updated += 1
  end
end

puts "=== done: #{updated} game(s) updated ==="
