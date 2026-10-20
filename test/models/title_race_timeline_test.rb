require "test_helper"

class TitleRaceTimelineTest < ActiveSupport::TestCase
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

  def timeline
    TitleRaceTimeline.new(@season)
  end

  test "each game ended is a moment to pick, in the order played, grouped by week" do
    play(2, [ 3, 1 ])
    play(3, [ 0, 2 ])
    play(9, [ 1, 0 ])

    points = timeline.points
    assert_equal [ "2026-05-02-alpha-beta", "2026-05-03-beta-alpha", "2026-05-09-alpha-gamma" ], points.map(&:key)
    assert_equal [ "5/2 Alpha-Beta", "5/3 Beta-Alpha", "5/9 Alpha-Gamma" ], points.map(&:short_label)
    assert_equal "5月9日のAlpha 1-0 Gamma（1回戦）", points.last.label
    assert_equal({ 1 => 2, 2 => 1 }, timeline.points_by_week.transform_values(&:size))
  end

  test "a moment's race counts only the games ended by then" do
    play(2, [ 3, 1 ])
    play(3, [ 0, 2 ])
    play(9, [ 3, 0 ])
    play(10, [ 0, 3 ]) # alpha has both cards

    line = timeline
    after_week1 = line.find("2026-05-03-beta-alpha")
    assert_equal [ "②Alpha-Gamma", "③Beta-Gamma" ], line.race(after_week1).cards.map(&:label)
    assert_equal [ @alpha ], line.race(line.find(nil)).settled
    assert_equal line.points.last, line.find("2026-05-04-alpha-beta") # no such game
  end

  test "the last game of a season over is its end, when the champion is named" do
    [ [ 2, [ 3, 1 ] ], [ 3, [ 0, 2 ] ], [ 9, [ 3, 0 ] ], [ 10, [ 0, 3 ] ], [ 16, [ 2, 1 ] ], [ 17, [ 1, 2 ] ] ].each { |day, score| play(day, score) }

    line = timeline
    assert_equal 6, line.points.size
    assert line.race(line.points.last).over?
  end

  test "a game after which too many cards matter to draw is left out" do
    play(2, [ 3, 1 ])
    play(3, [ 0, 2 ])
    line = timeline
    too_many = Struct.new(:applicable?, :too_many_cards?).new(true, true)

    stub_method(line, :race_after, ->(game) { game.played_on.day == 2 ? too_many : TitleRace.new(@season, after: game) }) do
      assert_equal [ "2026-05-03-beta-alpha" ], line.points.map(&:key)
    end
  end

  test "none before any result, and none for a season with no race" do
    assert_empty timeline.points
    assert_empty TitleRaceTimeline.new(Season.create!(year: 2020, term: "autumn")).points
  end
end
