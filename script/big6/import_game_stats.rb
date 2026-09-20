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
#
# On a small shared machine (Render runs this beside the web server) a run that
# keeps growing can get the whole container killed. So the script watches its
# own memory and, once it has grown more than MEMORY_GROWTH_LIMIT_MB (default
# 150) since starting, stops cleanly with exit status 75. Run the same command
# again to carry on; nothing is lost. script/big6/import_game_stats.sh does that
# for you, restarting the import each time it stops this way.
$stdout.sync = true # show progress as it happens, even when redirected to a log

# Only the columns the import uses: a Game row also carries JSON (the league's
# official box score) that thousands of games would hold in memory for nothing.
games = Game.with_stats_available.joins(:season)
  .where(seasons: { year: ENV.fetch("FROM_YEAR", 0).to_i..ENV.fetch("TO_YEAR", 9999).to_i })
  .order(:played_on, :game_number)
  .select(:id, :scorebook_game_id, :played_on)
games = games.where(stats_checked_at: nil) unless ENV["FORCE"]
games = games.to_a

memory_limit_mb = ENV.fetch("MEMORY_GROWTH_LIMIT_MB", 150).to_i
guard = MemoryGuard.new(growth_limit_mb: memory_limit_mb)

puts "#{games.size} games to fetch (about #{(games.size / 60.0).ceil} minutes)"
sums = Hash.new(0)
games.each_slice(50).with_index(1) do |slice, index|
  GameStatsImport.call(slice).each { |key, value| sums[key] += value }
  puts "#{[ index * 50, games.size ].min}/#{games.size} (through #{slice.last.played_on}) #{sums.to_a.map { |k, v| "#{k}=#{v}" }.join(' ')}"

  # Not after the last slice: there is nothing left to protect, and a finished run should end normally.
  if index * 50 < games.size && guard.exceeded?
    puts "stopping to avoid running out of memory: it has grown #{guard.growth_mb}MB (limit #{memory_limit_mb}MB). " \
         "Run the same command again to continue where it stopped."
    exit 75
  end
end
puts "done: #{sums.to_a.map { |k, v| "#{k}=#{v}" }.join(' ')}"
