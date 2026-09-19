# Links players to games using the GameMember lists already stored in each
# season's scorebook_games (2021 onward). No network access; run
# import_players.rb first so the players exist.
#
# Run with: bin/rails runner script/big6/import_game_members.rb
result = GameMemberImport.call
puts "games: #{result[:games]}, roster entries: #{result[:members]}, skipped (player not imported or listed twice): #{result[:skipped]}"
