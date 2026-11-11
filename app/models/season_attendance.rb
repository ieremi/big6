# 観衆 for a season's attendance tab (/seasons/:year/:term/attendance): the
# total and average over the games that have a figure, the same for the same
# term a year earlier (前年同季) to set them against, and the best-attended
# games. Only games with a result count, as in Standings, whose rows give each
# university's figures on the same page.
class SeasonAttendance
  attr_reader :season

  def initialize(season)
    @season = season
  end

  # The games with a result and a figure, in the order they were played.
  def games
    @games ||= season.games.where.not(attendance: nil).includes(:team0, :team1, :season)
      .order(:played_on, :game_number).select(&:decided?)
  end

  def count
    games.size
  end

  def total
    games.sum(&:attendance)
  end

  # Rounded to a whole number; nil without a game to take it over.
  def average
    (total.to_f / count).round if count.positive?
  end

  # The same over the games on a Saturday or a Sunday (Game#weekend?), as the
  # university table's 土日の1試合平均: weekday games draw far smaller crowds.
  def weekend_average
    weekend = games.select(&:weekend?)
    (weekend.sum(&:attendance).to_f / weekend.size).round if weekend.any?
  end

  # The same for the same term a year earlier, or nil if it has no figures.
  def previous
    return @previous if defined?(@previous)

    season = Season.find_by(year: @season.year - 1, term: @season.term)
    @previous = season && SeasonAttendance.new(season).then { |attendance| attendance if attendance.count.positive? }
  end

  # The best-attended games, most first (the earlier first when level).
  def top_games(limit = 10)
    games.sort_by.with_index { |game, i| [ -game.attendance, i ] }.first(limit)
  end
end
