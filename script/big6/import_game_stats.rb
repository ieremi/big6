# Imports each finished game's player box score (batting and pitching lines)
# from Scorebook's game pages: one request per game, one second apart, about
# 5,900 games in all. Run script/big6/import_players.rb first so the players
# exist. Safe to re-run: by default only games not yet fetched are tried, so
# an interrupted run resumes where it stopped.
#
# Limit the years with FROM_YEAR / TO_YEAR, and refetch games already tried
# with FORCE=1:
#   FROM_YEAR=2020 bin/rails runner script/big6/import_game_stats.rb
#   FORCE=1 FROM_YEAR=2025 bin/rails runner script/big6/import_game_stats.rb
$stdout.sync = true # show progress as it happens, even when redirected to a log

games = Game.with_stats_available.joins(:season)
  .where(seasons: { year: ENV.fetch("FROM_YEAR", 0).to_i..ENV.fetch("TO_YEAR", 9999).to_i })
  .order(:played_on, :game_number)
games = games.where(stats_checked_at: nil) unless ENV["FORCE"]
games = games.to_a

puts "#{games.size} games to fetch (about #{(games.size / 60.0).ceil} minutes)"
sums = Hash.new(0)
games.each_slice(50).with_index(1) do |slice, index|
  GameStatsImport.call(slice).each { |key, value| sums[key] += value }
  puts "#{[ index * 50, games.size ].min}/#{games.size} (through #{slice.last.played_on}) #{sums.to_a.map { |k, v| "#{k}=#{v}" }.join(' ')}"
end
puts "done: #{sums.to_a.map { |k, v| "#{k}=#{v}" }.join(' ')}"
