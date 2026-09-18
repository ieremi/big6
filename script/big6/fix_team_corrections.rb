# One-off data fix: 6 Game rows have team0_id == team1_id (a team
# "playing itself"), because Scorebook's own source data has
# topTeamId == bottomTeamId for these — confirmed directly against the raw
# scorebook_games entries, not an import bug. See known_team_corrections.rb
# for the reasoning behind each corrected opponent.
#
# game.rb already applies these same overrides on import (so a re-sync
# resolves team1 correctly from the start), so re-running this after a
# fresh import should just confirm "already correct" for all of them —
# this script is a safety net for a database that hasn't been re-synced
# since that fix landed.
#
# Run with: bin/rails runner script/big6/fix_team_corrections.rb
require_relative "known_team_corrections"

KNOWN_TEAM_CORRECTIONS.each do |scorebook_game_id, correction|
  game = Game.find_by(scorebook_game_id: scorebook_game_id)

  unless game
    warn "scorebook_game_id=#{scorebook_game_id}: not found, skipping"
    next
  end

  team1 = University.find_by(slug: correction[:team1_slug])

  if game.team1_id == team1.id && game.data_correction_note.present?
    puts "scorebook_game_id=#{scorebook_game_id} (#{game.played_on}): already #{team1.slug}, no change"
  else
    game.update!(team1: team1, data_correction_note: correction[:note])
    puts "scorebook_game_id=#{scorebook_game_id} (#{game.played_on}): team1 -> #{team1.slug}"
  end
end

remaining = Game.where("team0_id = team1_id").count
puts "remaining team0_id == team1_id rows: #{remaining}"
