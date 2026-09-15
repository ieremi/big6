class EstimatedGameSchedule
  # A rough assumption used only when a game hasn't been played yet and so has
  # no real duration: Big6 games are typically decided within about this long.
  DEFAULT_DURATION_MINUTES = 150 # 2h30m

  # When a day has more than one game (a doubleheader), only the first game's
  # start time is usually announced in advance. Later games are assumed to
  # start this many minutes after the previous one, which leaves a bit of
  # buffer beyond the assumed game length above for cleanup/warmup.
  GAME_INTERVAL_MINUTES = 180 # 3h

  def initialize(game)
    @game = game
  end

  # "HH:MM" if a schedule is known or can be derived, else nil.
  def scheduled_start_time
    own_start = detail_for(@game)["gameStartSchedule"]
    return own_start if own_start.present?

    # Scorebook doesn't have this game yet (e.g. a just-added decisive third
    # game) — fall back to what LeagueOfficialScheduleScraper published.
    official_start = @game.league_official_data&.dig("scheduledStartTime")
    return official_start if official_start.present?

    game_order = @game.game_order
    return nil unless game_order && game_order > 1

    first_game = sibling_game(game_order: 1)
    return nil unless first_game

    first_start = detail_for(first_game)["gameStartSchedule"]
    return nil if first_start.blank?

    add_minutes(first_start, GAME_INTERVAL_MINUTES * (game_order - 1))
  end

  # "HH:MM" if a start time is known/derivable, else nil.
  def estimated_end_time
    start = scheduled_start_time
    return nil unless start

    add_minutes(start, DEFAULT_DURATION_MINUTES)
  end

  private

  def detail_for(game)
    game.season.scorebook_game(game.scorebook_game_id) || {}
  end

  def sibling_game(game_order:)
    sibling = @game.season.games.find_by(played_on: @game.played_on, game_order: game_order)
    sibling&.tap { |g| g.season = @game.season }
  end

  def add_minutes(hhmm, minutes)
    hour, min = hhmm.split(":").map(&:to_i)
    total = (hour * 60 + min + minutes) % (24 * 60)
    format("%02d:%02d", total / 60, total % 60)
  end
end
