# One-off cleanup for databases where game.rb was run before it learned to
# skip "中止"/"ノーゲーム" Scorebook entries (see known_game_number_overrides.rb
# and the CANCELLED_STATUSES skip in game.rb). Those runs left behind
# "phantom" Game rows: no score, sharing (season, team pair, game_number)
# with another row that has a real score. This finds and removes exactly
# that pattern — it does NOT touch a genuine future/scheduled game (which
# would also have nil scores) because it only considers duplicate groups
# where a SIBLING already has a real result, and only rows dated in the past.
#
# Run with: bin/rails runner script/big6/delete_phantom_duplicate_games.rb

dupes = Game.group(:season_id, :team0_id, :team1_id, :game_number).having("count(*) > 1").count

deleted = 0
remaining_ambiguous = []

dupes.each_key do |season_id, team0_id, team1_id, game_number|
  games = Game.where(season_id: season_id, team0_id: team0_id, team1_id: team1_id, game_number: game_number).to_a

  scored, unscored = games.partition { |g| g.team0_score.present? && g.team1_score.present? }

  if scored.size == 1 && unscored.all? { |g| g.played_on < Date.current }
    unscored.each do |g|
      puts "deleting phantom id=#{g.id} played_on=#{g.played_on} scorebook_game_id=#{g.scorebook_game_id} " \
        "(kept id=#{scored.first.id} played_on=#{scored.first.played_on} #{scored.first.team0_score}-#{scored.first.team1_score})"
      g.destroy!
      deleted += 1
    end
  else
    remaining_ambiguous << games.map(&:id)
  end
end

puts "deleted #{deleted} phantom rows"

if remaining_ambiguous.any?
  puts "left #{remaining_ambiguous.size} group(s) untouched (not a clean 1-scored/N-unscored pattern):"
  remaining_ambiguous.each { |ids| puts "  Game ids: #{ids.join(', ')}" }
end

remaining = Game.group(:season_id, :team0_id, :team1_id, :game_number).having("count(*) > 1").count
puts "duplicate groups remaining: #{remaining.size}"
