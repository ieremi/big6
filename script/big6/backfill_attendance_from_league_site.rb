# One-off backfill: fills in the attendance of final games that Scorebook left
# blank, from each game's page on the league's site (big6.gr.jp), which gives
# it as 観衆. Scorebook had none for 2026 spring's 立大-東大 1回戦, 明大-法大
# 1回戦 and 慶大-法大 3回戦, whose pages give 10,000, 12,000 and 3,500.
#
# SyncRecentGamesJob does the same for new games now (fill_attendance), so
# this is only needed once for games from before that. Games behind closed
# doors (無観客試合, many in 2021's spring) have no attendance on the league's
# page either, and stay blank.
#
# Only games from 2005 on, when the league's pages start having box scores.
# The pages are read a second apart.
#
# Run with: bin/rails runner script/big6/backfill_attendance_from_league_site.rb
#   DRY_RUN=1  only lists the games that would be read

games = Game.joins(:season).includes(:season, :team0, :team1)
  .where(game_status: "試合終了", attendance: nil)
  .where(seasons: { year: LeagueOfficialGameScraper::MIN_YEAR.. })
  .order(:played_on, :game_order)
  .to_a

puts "#{games.size} final game(s) without attendance"
filled = 0

games.each_with_index do |game, index|
  label = "#{game.played_on} #{game.team0.short_name}-#{game.team1.short_name} #{game.game_number}回戦"
  if ENV["DRY_RUN"]
    puts "  #{label}"
    next
  end

  sleep 1 if index.positive?
  LeagueOfficialGameScraper.call(game)
  attendance = game.reload.attendance
  filled += 1 if attendance
  puts "  #{label}: #{attendance ? "#{attendance}人" : "なし（無観客など）"}"
rescue StandardError => e
  puts "  #{label}: #{e.class}: #{e.message}"
end

puts "=== done: #{filled} game(s) filled in ===" unless ENV["DRY_RUN"]
