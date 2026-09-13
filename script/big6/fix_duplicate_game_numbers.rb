# One-off data fix: 13 pairs of Game rows shared the same
# (season, team pair, game_number), because Scorebook gave the later game
# the same round label as an earlier one (confirmed cases: a championship
# playoff, a called/shortened game, and a handful of apparent Scorebook
# numbering slips). Keyed by scorebook_game_id (not local `Game#id`, which
# differs per database) so this can run against any environment's data.
#
# Run with: bin/rails runner script/big6/fix_duplicate_game_numbers.rb

RENUMBER = {
  1963110401 => 4,
  1951061901 => 3,
  1955101801 => 3,
  1952092301 => 3,
  1949102402 => 3,
  1976051001 => 3,
  1948061101 => 4,
  1949052202 => 3,
  1955050901 => 3,
  1995052201 => 4,
  1959111201 => 3,
  1990051501 => 4,
  1957091502 => 4
}.freeze

RENUMBER.each do |scorebook_game_id, new_number|
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
