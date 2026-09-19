require "test_helper"

class BattingLineTest < ActiveSupport::TestCase
  def line(**attributes)
    BattingLine.new({ pa: 4, ab: 3, runs: 1, hits: 1, doubles: 0, triples: 0, home_runs: 0, rbi: 0, strikeouts: 1, walks: 1, sacrifices: 0, stolen_bases: 0, gidp: 0, fielding_errors: 0 }.merge(attributes))
  end

  test "totals sums each column and counts the lines as games" do
    totals = BattingLine.totals([ line, line(ab: 4, hits: 2, home_runs: 1, rbi: 3) ])

    assert_equal [ 2, 8, 7, 3, 1, 3 ], [ totals.games, totals.pa, totals.ab, totals.hits, totals.home_runs, totals.rbi ]
  end

  test "average is hits over at-bats" do
    assert_in_delta 0.3333, BattingLine.totals([ line(ab: 3, hits: 1) ]).average, 0.0001
  end

  test "average is nil with no at-bats" do
    assert_nil BattingLine.totals([ line(ab: 0, hits: 0) ]).average
    assert_nil BattingLine.totals([]).average
  end
end
