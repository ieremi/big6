# The weeks a season's title race (TitleRace) can be looked at the end of, for
# the week buttons on the standings page: how the race stood once each week's
# cards were played, from the first week it can be counted
# (ChampionshipOdds::OPEN_CARDS cards or fewer open) to the latest.
#
# The end of a week is the day before the next week's first game: a game called
# off and played later counts in the week it was played, as it did then. The
# latest week the season has reached is the race as it stands now (as_of nil):
# over, or only partly played (in_progress) with the next games still to come.
class TitleRaceWeeks
  # A week to pick: its number (SeasonWeeks), the last day counted (as_of: nil
  # for now), the last day with a result by then (through), and whether the
  # week is still being played.
  Point = Struct.new(:week, :as_of, :through, :in_progress, keyword_init: true) do
    # "第5週終了時点（10月12日まで）", or "第6週（途中、10月18日まで）".
    def label
      through_label = through&.strftime("%-m月%-d日まで")
      in_progress ? "第#{week}週（途中#{"、#{through_label}" if through_label}）" : "第#{week}週終了時点#{"（#{through_label}）" if through_label}"
    end
  end

  attr_reader :games

  def initialize(season, games: nil)
    @season = season
    @games = games || TitleRace.games_of(season)
  end

  # The weeks to choose from, in order: those whose race has its grid to show
  # (or its champion), not a week when more than TitleRace::MAX_CARDS cards still
  # matter and the race only says so. None when the season has no race to show.
  def points
    @points ||= all_points
      .select { |point| open_cards(point.as_of) <= ChampionshipOdds::OPEN_CARDS }
      .select { |point| race(point).applicable? && !race(point).too_many_cards? }
  end

  # The point for the week asked for (the week param), or the latest one.
  def find(week)
    points.find { |point| point.week.to_s == week.to_s } || points.last
  end

  # The title race at the point (as it stands now for nil), worked out once for each.
  def race(point)
    @races ||= {}
    @races[point&.week] ||= TitleRace.new(@season, games: @games, as_of: point&.as_of)
  end

  private

  # A point for each week begun (one with a result in it), each ending the day
  # before the next week's first game; the last is now.
  def all_points
    weeks = SeasonWeeks.new(@games).weeks
    begun = weeks.select { |week| week.games.any?(&:decided?) }
    begun.each_with_index.map do |week, index|
      latest = index == begun.size - 1
      as_of = latest ? nil : weeks[weeks.index(week) + 1].games.map(&:played_on).min - 1
      Point.new(week: week.number, as_of: as_of, through: last_result_on(as_of), in_progress: latest && week.games.any? { |game| !game.decided? })
    end
  end

  # The day of the last result by the end of as_of (nil: of all).
  def last_result_on(as_of)
    @games.select { |game| game.decided? && (as_of.nil? || game.played_on <= as_of) }.map(&:played_on).max
  end

  # How many cards are still open at the end of as_of: pairs neither of which
  # had won two of their games by then.
  def open_cards(as_of)
    @games.group_by { |game| [ game.team0_id, game.team1_id ].sort }.count do |_, games|
      wins = games.select { |game| game.decided? && (as_of.nil? || game.played_on <= as_of) && game.team0_score != game.team1_score }
        .map { |game| game.team0_score > game.team1_score ? game.team0_id : game.team1_id }.tally
      wins.values.max.to_i < 2
    end
  end
end
