# Records cancellations (中止 / ノーゲーム) on games that were scheduled but never
# played, from the league's schedule page and from Scorebook. The hourly
# SyncRecentGamesJob does this for games of the last few days as they happen; this
# is for catching up, e.g. after the cancellation handling was first deployed, or
# after a stretch when the job wasn't running.
#
# It takes the seasons that have a game in the past with no score and no cancellation
# recorded (within the last DAYS days, 90 by default: older ones are old data with
# no result, not games waiting to be marked) and runs the schedule scraper and
# ScorebookSync for each. A season can be named instead.
#
# Run with: bin/rails runner script/big6/update_cancelled_games.rb
#           bin/rails runner script/big6/update_cancelled_games.rb 2026 autumn
#           DAYS=30 bin/rails runner script/big6/update_cancelled_games.rb

def unresolved_games(since)
  Game.not_cancelled.where(team0_score: nil, team1_score: nil).where(played_on: since...Date.current)
end

days = Integer(ENV.fetch("DAYS", 90))
seasons =
  if ARGV.size == 2
    [ Season.find_by!(year: ARGV[0], term: ARGV[1]) ]
  else
    Season.where(id: unresolved_games(Date.current - days).select(:season_id)).order(:year, :term).to_a
  end

if seasons.empty?
  puts "no past games without a result or a recorded cancellation"
  exit
end

seasons.each do |season|
  before = season.games.cancelled.count
  puts "#{season.title}: #{before} cancelled game(s) recorded"

  LeagueOfficialScheduleScraper.call(season)
  ScorebookSync.call(season)

  after = season.games.cancelled.count
  puts "  -> #{after} now (#{after - before} newly recorded)"
end

# What's still without a result and not known to be cancelled: games the
# sources don't call cancelled either (yet to be entered, or lost).
left = unresolved_games(Date.current - days).includes(:team0, :team1, :season).order(:played_on).to_a
puts "still without a result or a cancellation: #{left.size}"
left.each { |game| puts "  #{game.played_on} #{game.season.title} #{game.team0.short_name} - #{game.team1.short_name} (#{game.game_number}回戦, #{game.game_status.inspect})" }
