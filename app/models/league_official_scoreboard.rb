# Reads back the provisional box score cached by LeagueOfficialGameScraper
# on Game#league_official_data. Same read interface as GameScoreboard so
# views can fall back to this when Scorebook doesn't have full detail yet.
class LeagueOfficialScoreboard
  def initialize(game)
    @detail = game.league_official_data || {}
    @runs_top = @detail["runsTop"] || []
    @runs_bottom = @detail["runsBottom"] || []
  end

  def present?
    @detail.present?
  end

  # See GameScoreboard#innings.
  def innings
    played = (1..[ @runs_top.length, @runs_bottom.length ].max).select do |n|
      @runs_top[n - 1].present? || @runs_bottom[n - 1].present?
    end
    return played if played.empty?

    1..[ played.max, 9 ].max
  end

  def top_runs(inning)
    @runs_top[inning - 1]
  end

  def bottom_runs(inning)
    @runs_bottom[inning - 1]
  end

  # See GameScoreboard#top_total/#bottom_total.
  def top_total
    innings.sum { |n| top_runs(n).to_i }
  end

  def bottom_total
    innings.sum { |n| bottom_runs(n).to_i }
  end

  def top_hits
    @detail["hitsTop"]
  end

  def bottom_hits
    @detail["hitsBottom"]
  end

  def top_errors
    nil
  end

  def bottom_errors
    nil
  end

  def stadium
    @detail["stadium"]
  end

  def attendance
    @detail["attendance"]
  end

  def started_at
    @detail["startTime"]
  end

  def finished_at
    @detail["finishTime"]
  end

  def duration
    return nil unless duration_minutes

    "#{duration_minutes / 60}時間#{duration_minutes % 60}分"
  end

  def duration_minutes
    return nil unless started_at.present? && finished_at.present?

    start_h, start_m = started_at.split(":").map(&:to_i)
    finish_h, finish_m = finished_at.split(":").map(&:to_i)
    (finish_h * 60 + finish_m) - (start_h * 60 + start_m)
  end

  def umpires
    @detail["umpires"] || []
  end
end
