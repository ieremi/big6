# Adds a game Scorebook doesn't have from a transcription of a printed source
# (db/sources), with the source cited on its page. See SourceGameImport.
# Running it again updates the same game.
#
# The game's season must exist (db/seeds.rb).
#
# Run with: FILE=db/sources/rikkyo_yakyubushi_1981/1924_autumn.yml DATE=1924-09-24 \
#             bin/rails runner script/big6/import_source_game.rb

path = ENV.fetch("FILE")
played_on = Date.parse(ENV.fetch("DATE"))

game = SourceGameImport.call(path, played_on: played_on)
puts "#{game.played_on} #{game.team0.short_name} #{game.team0_score} - #{game.team1_score} #{game.team1.short_name} " \
     "(#{game.season.year} #{game.season.term} #{game.game_number}回戦, id #{game.id})"
