# Polls Scorebook (via ScorebookSync) for recently-played games until their
# full detail (final score + box score) has been fetched. Looks back several
# days, not just today, since Scorebook sometimes doesn't publish the
# complete box score until the day after a game (or later). Scheduled hourly
# in config/recurring.yml; a no-op, no-HTTP-call quick exit on days with no
# recent games at all.
#
# While a game is still incomplete in Scorebook, also fetches a provisional
# box score from the official league site (big6.gr.jp) via
# LeagueOfficialGameScraper, so the site has something to show in the
# meantime (see LeagueOfficialScoreboard). This is a stand-in only —
# whether polling continues is still decided by Scorebook completeness.
#
# Separately, and regardless of per-game completeness, also scrapes the
# official site's season schedule page (LeagueOfficialScheduleScraper) for
# any season with recent games, to pick up a decisive third game (3回戦) as
# soon as the league adds it — that only happens after the first two games
# split 1-1, so there's nothing to see until then, and it wouldn't be caught
# by looking at already-known Game rows alone.
#
# Also scrapes sportsbull.jp's BIG6TV schedule (SportsbullVideoScraper) for
# full match replay links for those same seasons — a game's replay usually
# isn't posted until sometime after it's played, so this needs to keep
# checking recent seasons rather than running once per game.
#
# And scrapes JMA's historical weather data (JmaWeatherScraper) for the
# (year, month) of each recent game — JMA usually has a day's data up
# within a day or so, not necessarily the same hour it's played.
#
# A game cancelled (中止) is reported by both Scorebook and the schedule page,
# and recorded on the game; it has no box score to wait for, so it is no longer
# polled.
#
# A game under way (試合中) has a score and innings too, but isn't complete, so it
# keeps being polled; RefreshLiveScoreboardsJob does that every five minutes.
#
# Finally, fetches each final game's player box score from Scorebook
# (GameStatsImport) once it has none, for the players' season and career stats.
class SyncRecentGamesJob < ApplicationJob
  queue_as :default

  LOOKBACK_DAYS = 3

  def perform
    games = Game.where(played_on: (Date.current - LOOKBACK_DAYS)..Date.current).includes(:team0, :team1, :season)
    return if games.none?

    seasons = games.map(&:season).uniq
    seasons.each { |season| LeagueOfficialScheduleScraper.call(season) }
    seasons.each { |season| SportsbullVideoScraper.call(season) }

    games.map { |game| [ game.played_on.year, game.played_on.month ] }.uniq.each do |year, month|
      JmaWeatherScraper.call(year, month)
    end

    # Reloaded, since the schedule pages may just have marked some cancelled.
    incomplete_games = games.reload.reject { |game| game.not_held? || complete?(game) }
    if incomplete_games.any?
      incomplete_games.map(&:season).uniq.each { |season| ScorebookSync.call(season) }
      incomplete_games.each { |game| LeagueOfficialGameScraper.call(game) }
    end

    import_player_stats(games)
  end

  private

  # Fetches player box scores for games that are now final but have none yet.
  # Scorebook can publish them a day late, so a game is retried on each run
  # while it is inside the lookback window.
  def import_player_stats(games)
    pending = Game.needing_stats.where(id: games.map(&:id)).to_a
    GameStatsImport.call(pending) if pending.any?
  end

  def complete?(game)
    game.decided? && GameScoreboard.new(game).innings.any?
  end
end
