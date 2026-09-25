# Checks a few players' batting lines against Scorebook's member pages each
# run (ScorebookStatsPlayerCheck), and records what it finds in the database:
# the players never checked first, then those checked longest ago, so every
# player with batting lines is checked in turn and then again.
#
# Scheduled in config/recurring.yml every 20 minutes through the small hours
# (Tokyo time), when no game is on and few people visit: one request per player,
# a second apart, so each run takes about a minute. A whole run at once would
# take hours on the machine the web server runs on (Render), and a script that
# long tends not to reach the end there.
#
# script/big6/check_scorebook_stats.rb reports what has been found.
class CheckScorebookStatsJob < ApplicationJob
  queue_as :default

  BATCH_SIZE = 40
  SLEEP_SECONDS = 1

  # A run still going when the next is due makes that one wait for nothing.
  limits_concurrency to: 1, key: ->(*) { "check_scorebook_stats" }, on_conflict: :discard

  # The players due a check: first the teammates of lines found filed under the
  # wrong game (priority_player_ids), then everyone with batting lines, oldest
  # check first.
  def self.players_due(limit)
    priority = Player.where(id: priority_player_ids).order(:id).limit(limit).to_a
    rest = Player.where(id: BattingLine.select(:player_id)).where.not(id: priority.map(&:id))
      .left_joins(:scorebook_stats_player_check)
      .order(Arel.sql("scorebook_stats_player_checks.checked_at ASC NULLS FIRST, players.id ASC"))
      .limit(limit - priority.size)
    priority + rest.to_a
  end

  # The players on the roster, in the game a pending FixSuggestion guesses, of
  # the university whose lines it gathers, not checked since the suggestion was
  # made: their lines are likely filed under the wrong game too, and the sooner
  # they are checked the sooner the suggestion has the team's whole box score.
  # (Games before 2021 have no roster, and wait for the players' turns.)
  def self.priority_player_ids
    GameMember
      .joins("INNER JOIN fix_suggestions ON fix_suggestions.game_id = game_members.game_id " \
             "AND fix_suggestions.university_id = game_members.university_id")
      .joins("LEFT JOIN scorebook_stats_player_checks ON scorebook_stats_player_checks.player_id = game_members.player_id")
      .where(fix_suggestions: { status: "pending", kind: "misfiled_lines" })
      .where("scorebook_stats_player_checks.checked_at IS NULL OR scorebook_stats_player_checks.checked_at < fix_suggestions.created_at")
      .distinct.pluck(:player_id)
  end

  def perform(batch_size: BATCH_SIZE, sleep_seconds: SLEEP_SECONDS)
    # Our batting lines change as games are imported, and with them whether a
    # suggestion has anything left to fix.
    FixSuggestion.classify_undecided!

    self.class.players_due(batch_size).each do |player|
      ScorebookStatsPlayerCheck.run(player)
      sleep sleep_seconds
    rescue StandardError => e
      # One player's failure shouldn't stop the others; the player stays due, and comes up again next run.
      Rails.logger.error("CheckScorebookStatsJob: player #{player.scorebook_id}: #{e.class}: #{e.message}")
    end
  end
end
