module IcsGameEvent
  module_function

  CIRCLED_DIGITS = %w[① ② ③ ④ ⑤ ⑥ ⑦ ⑧ ⑨ ⑩].freeze

  def add_to(calendar, game)
    scoreboard = GameScoreboard.new(game)
    start_time, end_time = times_for(game, scoreboard)

    summary = "#{game.team0.short_name} vs #{game.team1.short_name}#{circled_number(game.game_number)}"

    calendar.add_event(
      uid: "game-#{game.id}@big6",
      summary: summary,
      start_time: start_time,
      end_time: end_time,
      all_day_date: start_time ? nil : game.played_on,
      location: StadiumLocation.for(scoreboard.stadium),
      description: "#{game.season.title} 第#{game.game_number}回戦"
    )
  end

  def times_for(game, scoreboard)
    if scoreboard.started_at.present?
      start_time = parse_japanese_time(game.played_on, scoreboard.started_at)
      end_time = scoreboard.finished_at.present? ? parse_japanese_time(game.played_on, scoreboard.finished_at) : nil
      return [ start_time, end_time ] if start_time
    end

    if game.played_on > Date.current
      estimate = EstimatedGameSchedule.new(game)
      start_str = estimate.scheduled_start_time
      if start_str
        start_time = parse_hhmm(game.played_on, start_str)
        end_str = estimate.estimated_end_time
        end_time = end_str ? parse_hhmm(game.played_on, end_str) : nil
        return [ start_time, end_time ]
      end
    end

    [ nil, nil ]
  end

  # e.g. "14時02分"
  def parse_japanese_time(date, text)
    match = text.match(/(\d+)時(\d+)分/)
    return nil unless match

    to_jst(date, match[1].to_i, match[2].to_i)
  end

  # e.g. "14:00"
  def parse_hhmm(date, text)
    hour, min = text.split(":").map(&:to_i)
    to_jst(date, hour, min)
  end

  def to_jst(date, hour, min)
    ActiveSupport::TimeZone["Asia/Tokyo"].local(date.year, date.month, date.day, hour, min)
  end

  def circled_number(n)
    CIRCLED_DIGITS[n - 1] || "(#{n})"
  end
end
