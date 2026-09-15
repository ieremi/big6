# Backfills video_url on Game rows from sportsbull.jp's BIG6TV schedule
# pages, one HTTP request per season. Only seasons from around 2023 onward
# have full match replay links (older ones only have highlight reels, which
# SportsbullVideoScraper deliberately ignores), so this is quick even
# though it walks every season.
#
# Ongoing games are also covered by SyncRecentGamesJob (hourly), which
# calls SportsbullVideoScraper for any season with a game in the last few
# days — this script is for a one-off backfill or a database that hasn't
# run that job yet.
#
# Run with: bin/rails runner script/big6/scrape_sportsbull_videos.rb

total = 0

Season.order(:year, :term).each do |season|
  games = SportsbullVideoScraper.call(season)
  next if games.empty?

  total += games.size
  puts "#{season.title}: #{games.size} video link(s)"
end

puts "=== done: #{total} video link(s) total ==="
