# Backfills weather_summary/temp_high/temp_low on Game rows from JMA's
# historical Tokyo weather data, one request per (year, month) that has a
# game — around 400 requests for the site's full ~100-year history, so this
# sleeps briefly between requests to stay polite to a government server.
#
# Ongoing games are also covered by SyncRecentGamesJob (hourly), which
# calls JmaWeatherScraper for any (year, month) with a game in the last few
# days — this script is for a one-off backfill or a database that hasn't
# run that job yet.
#
# Run with: bin/rails runner script/big6/scrape_weather.rb

REQUEST_INTERVAL = 0.5 # seconds

year_months = Game.distinct.pluck(:played_on).map { |d| [ d.year, d.month ] }.uniq.sort

total = 0

year_months.each do |year, month|
  games = JmaWeatherScraper.call(year, month)
  total += games.size
  puts "#{year}-#{format("%02d", month)}: #{games.size} game(s) updated" if games.any?
  sleep REQUEST_INTERVAL
end

puts "=== done: #{total} game(s) updated total ==="
