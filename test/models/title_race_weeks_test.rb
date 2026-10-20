require "test_helper"

class TitleRaceWeeksTest < ActiveSupport::TestCase
  setup do
    Game.delete_all
    @season = seasons(:one)
    @alpha = universities(:one)
    @beta = universities(:two)
    @gamma = University.create!(name: "Gamma University", short_name: "Gamma", slug: "gamma", position: 3)
    # Week 1 (5/2-3) alpha v beta, week 2 (5/9-10) alpha v gamma, week 3 (5/16-17) beta v gamma.
    [ [ @alpha, @beta, 2, 1 ], [ @beta, @alpha, 3, 2 ], [ @alpha, @gamma, 9, 1 ], [ @gamma, @alpha, 10, 2 ], [ @beta, @gamma, 16, 1 ], [ @gamma, @beta, 17, 2 ] ]
      .each { |team0, team1, day, number| Game.create!(season: @season, team0: team0, team1: team1, played_on: Date.new(2026, 5, day), game_number: number) }
  end

  def play(day, score)
    Game.find_by!(played_on: Date.new(2026, 5, day)).update!(team0_score: score.first, team1_score: score.last, game_status: "試合終了")
  end

  def points
    TitleRaceWeeks.new(@season).points
  end

  test "each week begun is a point, ending the day before the next week's first game, the latest as it stands now" do
    play(2, [ 3, 1 ])
    play(3, [ 0, 2 ])
    play(9, [ 1, 0 ])

    assert_equal [ [ 1, Date.new(2026, 5, 8), Date.new(2026, 5, 3), false ], [ 2, nil, Date.new(2026, 5, 9), true ] ],
      points.map { |point| [ point.week, point.as_of, point.through, point.in_progress ] }
    assert_equal [ "第1週終了時点（5月3日まで）", "第2週（途中、5月9日まで）" ], points.map(&:label)
  end

  test "a week's race counts only the games played by its end" do
    play(2, [ 3, 1 ])
    play(3, [ 0, 2 ])
    play(9, [ 3, 0 ])
    play(10, [ 0, 3 ]) # alpha has both cards

    weeks = TitleRaceWeeks.new(@season)
    week1, week2 = weeks.points
    assert_equal [ "②Alpha-Gamma", "③Beta-Gamma" ], weeks.race(week1).cards.map(&:label)
    assert_equal [ @alpha ], weeks.race(week2).settled
    assert_equal week1, weeks.find("1")
    assert_equal week2, weeks.find(nil)
    assert_equal week2, weeks.find("9")
  end

  test "the last week of a season over is its end, when the champion is named" do
    [ [ 2, [ 3, 1 ] ], [ 3, [ 0, 2 ] ], [ 9, [ 3, 0 ] ], [ 10, [ 0, 3 ] ], [ 16, [ 2, 1 ] ], [ 17, [ 1, 2 ] ] ].each { |day, score| play(day, score) }

    weeks = TitleRaceWeeks.new(@season)
    assert_equal [ "第1週終了時点（5月3日まで）", "第2週終了時点（5月10日まで）", "第3週終了時点（5月17日まで）" ], weeks.points.map(&:label)
    assert weeks.race(weeks.points.last).over?
  end

  test "a week whose race has too many cards mattering to draw is left out" do
    play(2, [ 3, 1 ])
    play(3, [ 0, 2 ])
    play(9, [ 1, 0 ])
    weeks = TitleRaceWeeks.new(@season)
    races = { 1 => Struct.new(:applicable?, :too_many_cards?).new(true, true), 2 => TitleRace.new(@season) }

    stub_method(weeks, :race, ->(point) { races.fetch(point.week) }) do
      assert_equal [ 2 ], weeks.points.map(&:week)
      assert_equal 2, weeks.find("1").week
    end
  end

  test "no week before any result, and none for a season with no race" do
    assert_empty points
    assert_empty TitleRaceWeeks.new(Season.create!(year: 2020, term: "autumn")).points
  end
end
