# Imports Scorebook's member roster (名鑑) into the players table. Safe to
# re-run: members are upserted by Scorebook id and nothing is deleted. Makes
# one request per page of 20 members per entry year, one second apart.
#
# Limit the years with FROM_YEAR / TO_YEAR (default: 1872 through this year):
#   FROM_YEAR=2020 bin/rails runner script/big6/import_players.rb
#
# Some staff (部長, 監督, ...) have no entry year and are missed by the above.
# UNDATED=1 finds them by paging through every member (about ten minutes):
#   UNDATED=1 bin/rails runner script/big6/import_players.rb
result =
  if ENV["UNDATED"]
    PlayerSync.call_undated
  else
    PlayerSync.call(
      from_year: ENV.fetch("FROM_YEAR", PlayerSync::FIRST_YEAR).to_i,
      to_year: ENV.fetch("TO_YEAR", Date.current.year).to_i
    )
  end
puts "players imported: #{result[:imported]}, skipped: #{result[:skipped]}"
puts "players in database: #{Player.count}"
