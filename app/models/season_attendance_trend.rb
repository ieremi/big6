# Weekly cumulative attendance for a season, compared against the same term
# (spring/autumn) one year earlier — used for the line chart on the season
# page. Weeks are compared by number (week 1 vs week 1, etc.), not by
# calendar date, since the same week number can fall on different dates
# year to year.
class SeasonAttendanceTrend
  Point = Struct.new(:week, :cumulative, keyword_init: true)

  def initialize(season)
    @season = season
  end

  def current_label
    @season.title
  end

  def previous_label
    previous_season&.title
  end

  def current_points
    @current_points ||= weekly_cumulative(@season)
  end

  def previous_points
    @previous_points ||= weekly_cumulative(previous_season)
  end

  def any_data?
    current_points.any? || previous_points.any?
  end

  private

  def previous_season
    @previous_season ||= Season.find_by(year: @season.year - 1, term: @season.term)
  end

  # Stops at the last week with a finished game — a week that's only
  # partly (or not yet) played would otherwise flatten out the line instead
  # of just ending it, which reads as "attendance stopped" rather than
  # "not played yet".
  def weekly_cumulative(season)
    return [] unless season

    games = season.games.includes(:team0, :team1)
    weeks = SeasonWeeks.new(games).weeks
    cumulative = 0
    points = []

    weeks.each do |week|
      finished_games = week.games.select(&:decided?)
      break if finished_games.empty?

      cumulative += finished_games.filter_map(&:attendance).sum
      points << Point.new(week: week.number, cumulative: cumulative)
    end

    # A single real point can't draw a line — anchor it at a virtual
    # "week 0, 0 people" start so there's always a segment to show, even
    # right after week 1 finishes.
    points.any? ? [ Point.new(week: 0, cumulative: 0), *points ] : points
  end
end
