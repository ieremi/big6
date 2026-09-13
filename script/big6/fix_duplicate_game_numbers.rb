# One-off data fix: 13 pairs of Game rows shared the same
# (season, team pair, game_number), because Scorebook gave the later game
# the same round label as an earlier one (confirmed cases: a championship
# playoff, a called/shortened game, and a handful of apparent Scorebook
# numbering slips). Keyed by scorebook_game_id (not local `Game#id`, which
# differs per database) so this can run against any environment's data.
#
# game.rb already applies these same overrides on import (see
# known_game_number_overrides.rb, shared with that script), so re-running
# this after a fresh import should just confirm "no change" for all of
# them — this script is a safety net for a database that hasn't been
# re-synced since that fix landed.
#
# Run with: bin/rails runner script/big6/fix_duplicate_game_numbers.rb
require_relative "known_game_number_overrides"

KNOWN_GAME_NUMBER_OVERRIDES.each do |scorebook_game_id, new_number|
  game = Game.find_by(scorebook_game_id: scorebook_game_id)

  unless game
    warn "scorebook_game_id=#{scorebook_game_id}: not found, skipping"
    next
  end

  old_number = game.game_number
  if old_number == new_number
    puts "scorebook_game_id=#{scorebook_game_id} (#{game.played_on}): already #{new_number}, no change"
  else
    game.update_column(:game_number, new_number)
    puts "scorebook_game_id=#{scorebook_game_id} (#{game.played_on}): #{old_number} -> #{new_number}"
  end
end

remaining = Game.group(:season_id, :team0_id, :team1_id, :game_number).having("count(*) > 1").count
puts "remaining duplicate (season, team pair, game_number) groups: #{remaining.size}"
remaining.each_key { |key| puts "  #{key.inspect}" }
