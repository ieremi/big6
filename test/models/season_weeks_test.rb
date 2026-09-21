require "test_helper"

class SeasonWeeksTest < ActiveSupport::TestCase
  setup do
    @alpha = universities(:one)
    @beta = universities(:two)
    @gamma = University.create!(name: "Gamma University", short_name: "Gamma", slug: "gamma", position: 3)
    season = Season.create!(year: 2003, term: "spring")
    Game.create!(season: season, team0: @alpha, team1: @beta, played_on: "2003-04-05", game_number: 1)
    Game.create!(season: season, team0: @beta, team1: @gamma, played_on: "2003-04-12", game_number: 1)
    Game.create!(season: season, team0: @alpha, team1: @gamma, played_on: "2003-04-19", game_number: 1)
    @weeks = SeasonWeeks.new(season.games.includes(:team0, :team1).order(:played_on, :game_number))
  end

  test "weeks_with no universities is every week" do
    assert_equal [ 1, 2, 3 ], @weeks.weeks_with(nil).map(&:number)
    assert_equal [ 1, 2, 3 ], @weeks.weeks_with([]).map(&:number)
  end

  test "weeks_with universities keeps the weeks in which one of them played, under their own numbers" do
    assert_equal [ 2, 3 ], @weeks.weeks_with([ @gamma.id ]).map(&:number)
    assert_equal [ 1, 3 ], @weeks.weeks_with([ @alpha.id ]).map(&:number)
    assert_equal [ 1, 2, 3 ], @weeks.weeks_with([ @alpha.id, @beta.id ]).map(&:number)
  end

  test "weeks_with leaves out the series and games the universities were not in, and does not change the weeks" do
    week = @weeks.weeks_with([ @beta.id ]).find { |w| w.number == 2 }

    assert_equal 1, week.series.size
    assert_equal [ Date.new(2003, 4, 12) ], week.games.map(&:played_on)
    assert_equal [ 1, 2, 3 ], @weeks.weeks.map(&:number)
    assert_equal 1, @weeks.weeks.first.series.size
  end

  # ---- cancelled games

  # Two pairs, one week: both were rained out on the Saturday and played on Sunday
  # and Monday. rows_for_cancelled says which of the cancelled games we have a row for.
  def week_with_rained_out_pairs(rows_for_cancelled:, year: 2010)
    @rained_out ||= %w[a b c d].to_h { |slug| [ slug, University.create!(name: "#{slug} University", short_name: slug, slug: "u#{slug}", position: 10 + slug.ord - 96) ] }
    season = Season.create!(year: year, term: "spring")
    game = ->(day, x, y, number, **attributes) { Game.create!({ season: season, team0: @rained_out[x], team1: @rained_out[y], played_on: day, game_number: number }.merge(attributes)) }

    game.call("#{year}-05-15", "a", "b", 1, game_status: "中止") if rows_for_cancelled.include?(:ab)
    game.call("#{year}-05-16", "a", "b", 1, game_status: "試合終了", team0_score: 1, team1_score: 0)
    game.call("#{year}-05-17", "a", "b", 2, game_status: "試合終了", team0_score: 2, team1_score: 0)
    game.call("#{year}-05-15", "c", "d", 1, game_status: "中止") if rows_for_cancelled.include?(:cd)
    game.call("#{year}-05-16", "c", "d", 1, game_status: "試合終了", team0_score: 1, team1_score: 0)
    game.call("#{year}-05-17", "c", "d", 2, game_status: "試合終了", team0_score: 3, team1_score: 1)

    SeasonWeeks.new(season.games.includes(:team0, :team1).order(:played_on, :game_number))
  end

  test "a game cancelled on the first day does not start its series a day before the others" do
    shapes = [ [], [ :ab ], [ :cd ], [ :ab, :cd ] ].each_with_index.map do |cancelled, index|
      weeks = week_with_rained_out_pairs(rows_for_cancelled: cancelled, year: 2010 + index).weeks
      [ weeks.map(&:number), weeks.map { |week| week.games.count { |game| !game.not_held? } }, weeks.map { |week| week.series.size } ]
    end

    # One week of four games in two series, whichever of the cancelled games we have a row for.
    assert_equal [ [ [ 1 ], [ 4 ], [ 2 ] ] ] * 4, shapes
  end

  test "the cancelled game is still in its series, and the heading follows the game held" do
    week = week_with_rained_out_pairs(rows_for_cancelled: [ :ab, :cd ]).weeks.first

    assert_equal 3, week.series.first.games.size
    assert_equal [ true, false, false ], week.series.first.games.map(&:not_held?)
    assert_equal "a vs b、c vs d", week.heading
  end

  test "a series with nothing held but cancelled games still forms its own week" do
    a = University.create!(name: "a University", short_name: "a", slug: "ua", position: 11)
    b = University.create!(name: "b University", short_name: "b", slug: "ub", position: 12)
    season = Season.create!(year: 2011, term: "spring")
    Game.create!(season: season, team0: a, team1: b, played_on: "2011-05-14", game_number: 1, game_status: "中止")

    weeks = SeasonWeeks.new(season.games.includes(:team0, :team1)).weeks

    assert_equal [ 1 ], weeks.map(&:number)
    assert_equal [ Date.new(2011, 5, 14) ], weeks.first.games.map(&:played_on)
  end
end
