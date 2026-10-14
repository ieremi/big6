# Adds games Scorebook doesn't have from transcriptions of a printed source
# (db/sources), with the source cited on their pages. See SourceGameImport.
# Running it again updates the same games.
#
# With DATE, the one game of FILE on that day. Without it, every game of FILE
# that has a line score, and the season's printed standings; FILE may be a
# glob, e.g. every file of a book. The seasons must exist (db/seeds.rb).
#
# Run with: FILE=db/sources/rikkyo_yakyubushi_1981/1924_autumn.yml DATE=1924-09-24 \
#             bin/rails runner script/big6/import_source_game.rb
#           FILE='db/sources/rikkyo_yakyubushi_1981/*.yml' bin/rails runner script/big6/import_source_game.rb

def describe(game)
  "#{game.played_on} #{game.team0.short_name} #{game.team0_score} - #{game.team1_score} #{game.team1.short_name} " \
    "(#{game.season.year} #{game.season.term} #{game.game_number}回戦)"
end

if ENV["DATE"]
  puts describe(SourceGameImport.call(ENV.fetch("FILE"), played_on: Date.parse(ENV["DATE"])))
else
  Dir[ENV.fetch("FILE")].sort.each do |path|
    games, skipped = SourceGameImport.season(path)
    puts "#{path}: #{games.size} games#{", skipped #{skipped.join(", ")} (no line score)" if skipped.any?}"
  end
end
