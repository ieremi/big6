require "test_helper"

class PitchingLineTest < ActiveSupport::TestCase
  def line(**attributes)
    PitchingLine.new({ batters_faced: 13, outs: 10, hits: 4, home_runs: 0, walks: 1, strikeouts: 2, runs: 3, earned_runs: 3, pitches: 58, started: 1, complete_game: 0, shutout: 0, wins: 0, losses: 1 }.merge(attributes))
  end

  test "totals sums each column and counts the lines as games" do
    totals = PitchingLine.totals([ line, line(outs: 27, earned_runs: 1, wins: 1, losses: 0, complete_game: 1) ])

    assert_equal [ 2, 37, 4, 1, 1, 1 ], [ totals.games, totals.outs, totals.earned_runs, totals.wins, totals.losses, totals.complete_game ]
  end

  test "era is earned runs per nine innings" do
    assert_in_delta 1.0, PitchingLine.totals([ line(outs: 27, earned_runs: 1) ]).era, 0.0001
    assert_in_delta 8.1, PitchingLine.totals([ line(outs: 10, earned_runs: 3) ]).era, 0.0001
  end

  test "era is nil when no out was recorded" do
    assert_nil PitchingLine.totals([ line(outs: 0, earned_runs: 2) ]).era
  end

  test "innings_label writes outs the way baseball writes innings" do
    assert_equal "0", PitchingLine.innings_label(0)
    assert_equal "0 2/3", PitchingLine.innings_label(2)
    assert_equal "3", PitchingLine.innings_label(9)
    assert_equal "3 1/3", PitchingLine.innings_label(10)
    assert_equal "50 1/3", PitchingLine.innings_label(151)
  end
end
