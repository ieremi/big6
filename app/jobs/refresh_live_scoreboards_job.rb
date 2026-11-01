# Refreshes the scoreboard of each game that is on, every five minutes
# (config/recurring.yml): a game under way (試合中), or one still marked 試合前
# whose scheduled start has passed, which is to say one that has probably begun
# and that we haven't heard about yet. A game's scoreboard is part of its
# season's Scorebook data, so this is ScorebookSync for the season, without the
# bench members (a whole season's worth, and they don't change during a game),
# and for a game Scorebook still hasn't finished, the provisional box score from
# the league's site, as SyncRecentGamesJob does once an hour — which also carries
# a provisional lineup (LeagueOfficialLineup reads it back), Scorebook's own
# GameMember list not existing yet either at this point.
#
# It costs nothing when no game is on: one or two queries, and no request. Only
# games of today and yesterday count when under way (one can run past midnight):
# an older game still marked 試合中 is stale data, not a game to poll every five
# minutes for good; SyncRecentGamesJob and script/big6/update_cancelled_games.rb
# deal with those. A game still marked 試合前 is asked about for START_WINDOW from
# its scheduled start, and no longer: if it hasn't begun by then, or was called
# off, the hourly job will find that out.
#
# A game about to start (LINEUP_LEAD before its scheduled start) has its page on
# the league's site read too, for the starting lineup (スタメン), which appears
# there some half an hour before the game: on 2026-11-01 it was up 23 minutes
# before a 13:00 start. That is the league site alone: Scorebook has nothing
# new before the first pitch.
class RefreshLiveScoreboardsJob < ApplicationJob
  queue_as :default

  TOKYO = ActiveSupport::TimeZone["Asia/Tokyo"]

  # How long after its scheduled start a game still marked 試合前 is asked about.
  # The games of a day start three hours apart (EstimatedGameSchedule), so the
  # next one's window begins as this one's ends.
  START_WINDOW = 3.hours

  # How long before its scheduled start a game's page is read for the starting lineup.
  LINEUP_LEAD = 45.minutes

  # A run that is still going when the next is due makes that one wait for nothing.
  limits_concurrency to: 1, key: ->(*) { "refresh_live_scoreboards" }, on_conflict: :discard

  def perform
    live = live_games
    starting = starting_games
    return if live.empty? && starting.empty?

    live.map(&:season).uniq.each do |season|
      attempt("Scorebook #{season.title}") { ScorebookSync.call(season, members: false) }
    end

    # Some of them may be over (or called off) now, and need no provisional data.
    (live_games + starting).uniq.each { |game| attempt("league site #{game.season.title} #{game.played_on}") { LeagueOfficialGameScraper.call(game) } }
  end

  private

  # The games that are on at now: under way, or due to have started. The dates are
  # the calendar dates in Tokyo, where the games are played (the app's time zone is UTC).
  def live_games(now = TOKYO.now)
    today = now.to_date
    under_way = Game.in_progress.where(played_on: (today - 1)..today)
    not_yet_marked = Game.scheduled.where(played_on: today).includes(:season).select { |game| started?(game, now) }

    (under_way.includes(:season, :team0, :team1).to_a + not_yet_marked).uniq
  end

  # Today's games still 試合前 whose scheduled start is less than LINEUP_LEAD away.
  def starting_games(now = TOKYO.now)
    Game.scheduled.where(played_on: now.to_date).includes(:season, :team0, :team1).select do |game|
      starts_at = starts_at(game)
      starts_at && now >= starts_at - LINEUP_LEAD && now < starts_at
    end
  end

  # Whether the game's scheduled start (Tokyo time) has passed, but not by START_WINDOW yet.
  def started?(game, now)
    starts_at = starts_at(game)
    starts_at.present? && now >= starts_at && now < starts_at + START_WINDOW
  end

  # The game's scheduled start, in Tokyo, or nil when it isn't known.
  def starts_at(game)
    start = EstimatedGameSchedule.new(game).scheduled_start_time
    return nil if start.blank?

    hour, minute = start.split(":").map(&:to_i)
    TOKYO.local(game.played_on.year, game.played_on.month, game.played_on.day, hour, minute)
  end

  # One source being down shouldn't stop the others, or fail the job: the next run is five minutes away.
  def attempt(what)
    yield
  rescue StandardError => e
    Rails.logger.error("RefreshLiveScoreboardsJob: #{what}: #{e.class}: #{e.message}")
  end
end
