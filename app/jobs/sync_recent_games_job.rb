# Polls Scorebook (via ScorebookSync) for recently-played games until their
# full detail (final score + box score) has been fetched. Looks back several
# days, not just today, since Scorebook sometimes doesn't publish the
# complete box score until the day after a game (or later). Scheduled hourly
# in config/recurring.yml; a no-op, no-HTTP-call quick exit once there's
# nothing incomplete in the window.
class SyncRecentGamesJob < ApplicationJob
  queue_as :default

  LOOKBACK_DAYS = 3

  def perform
    games = Game.where(played_on: (Date.current - LOOKBACK_DAYS)..Date.current).includes(:season)
    incomplete_games = games.reject { |game| complete?(game) }
    return if incomplete_games.empty?

    incomplete_games.map(&:season).uniq.each { |season| ScorebookSync.call(season) }
  end

  private

  def complete?(game)
    game.team0_score.present? && game.team1_score.present? && GameScoreboard.new(game).innings.any?
  end
end
