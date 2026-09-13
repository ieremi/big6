# Runs the full "bring the database up to date" sequence in the right
# order, so nothing (especially the duplicate game_number fix) gets
# forgotten after a fresh import or a full DB rebuild.
#
# Run with: bin/rails runner script/big6/full_sync.rb

steps = [
  "scorebook/season.rb",
  "scorebook/season_games.rb",
  "game.rb",
  "fix_duplicate_game_numbers.rb"
]

steps.each do |relative_path|
  path = File.expand_path(relative_path, __dir__)
  puts "=== #{relative_path} ==="
  load(path)
  puts
end

puts "=== done ==="
