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

  # The players due a check, oldest check first.
  def self.players_due(limit)
    Player.where(id: BattingLine.select(:player_id))
      .left_joins(:scorebook_stats_player_check)
      .order(Arel.sql("scorebook_stats_player_checks.checked_at ASC NULLS FIRST, players.id ASC"))
      .limit(limit)
  end

  def perform(batch_size: BATCH_SIZE, sleep_seconds: SLEEP_SECONDS)
    self.class.players_due(batch_size).each do |player|
      ScorebookStatsPlayerCheck.run(player)
      sleep sleep_seconds
    rescue StandardError => e
      # One player's failure shouldn't stop the others; the player stays due, and comes up again next run.
      Rails.logger.error("CheckScorebookStatsJob: player #{player.scorebook_id}: #{e.class}: #{e.message}")
    end
  end
end
