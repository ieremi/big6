# Records cancellations (中止 / ノーゲーム) on games that were scheduled but never
# played. The hourly SyncRecentGamesJob does this for games of the last few days as
# they happen; this is for catching up, e.g. after the cancellation handling was
# first deployed, or after a stretch when the job wasn't running.
#
# It does two things:
#
# 1. From the Scorebook data already stored on every season (no network): marks the
#    games we have for Scorebook's cancelled entries. This finds the games left
#    over from before the importers skipped cancelled entries: rows with no result
#    and no status, which show as "試合中" for good, and can hide the real game of
#    the same round number. (delete_phantom_duplicate_games.rb misses those whose
#    home/away order differs from the replay's.) A game Scorebook has as finished is
#    left alone.
# 2. From the league's schedule page and Scorebook (network): for the seasons that
#    have a game in the past with no score and no cancellation recorded, within the
#    last DAYS days (90 by default; older ones are old data with no result, not
#    games waiting to be marked), runs the schedule scraper and ScorebookSync.
#
# A season can be named instead, and then both steps are for that season only.
#
# Run with: bin/rails runner script/big6/update_cancelled_games.rb
#           bin/rails runner script/big6/update_cancelled_games.rb 2024 autumn
#           DAYS=30 bin/rails runner script/big6/update_cancelled_games.rb

def unresolved_games(since)
  Game.not_cancelled.where(team0_score: nil, team1_score: nil).where(played_on: since...Date.current)
end

def describe(game)
  "#{game.played_on} #{game.team0.short_name} - #{game.team1.short_name} (#{game.game_number}回戦)"
end

days = Integer(ENV.fetch("DAYS", 90))
named = ARGV.size == 2 ? Season.find_by!(year: ARGV[0], term: ARGV[1]) : nil

puts "== from the stored Scorebook data"
stored_seasons = named ? [ named ] : Season.where.not(scorebook_games: nil).order(:year, :term)
marked = 0
stored_seasons.each do |season|
  games = ScorebookSync.new(season).record_stored_cancellations
  next if games.empty?

  puts "#{season.title}:"
  games.each { |game| puts "  marked #{describe(Game.includes(:team0, :team1).find(game.id))}" }
  marked += games.size
end
puts "#{marked} game(s) newly marked as cancelled"

puts "== from the schedule page and Scorebook"
seasons = named ? [ named ] : Season.where(id: unresolved_games(Date.current - days).select(:season_id)).order(:year, :term).to_a

if seasons.empty?
  puts "no past games without a result or a recorded cancellation"
else
  seasons.each do |season|
    before = season.games.cancelled.count
    LeagueOfficialScheduleScraper.call(season)
    ScorebookSync.call(season)
    after = season.games.cancelled.count
    puts "#{season.title}: #{before} -> #{after} cancelled game(s) recorded"
  end
end

# What's still without a result and not known to be cancelled: games the
# sources don't call cancelled either (yet to be entered, or lost).
left = unresolved_games(Date.current - days).includes(:team0, :team1, :season).order(:played_on).to_a
puts "still without a result or a cancellation: #{left.size}"
left.each { |game| puts "  #{game.season.title} #{describe(game)} #{game.game_status.inspect}" }
