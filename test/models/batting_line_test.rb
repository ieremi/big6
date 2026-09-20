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

  # AB 8, hits 3, walks 1, total bases 6 across two games.
  def ops_totals
    BattingLine.totals([ line(ab: 4, hits: 2, walks: 1, total_bases: 5), line(ab: 4, hits: 1, walks: 0, total_bases: 1) ])
  end

  test "on-base percentage is hits plus walks over at-bats plus walks" do
    assert_in_delta 4 / 9.0, ops_totals.on_base_percentage, 0.0001
  end

  test "slugging percentage is total bases over at-bats" do
    assert_in_delta 6 / 8.0, ops_totals.slugging_percentage, 0.0001
  end

  test "ops is on-base plus slugging, worked out from the summed totals" do
    assert_in_delta 4 / 9.0 + 6 / 8.0, ops_totals.ops, 0.0001
  end

  test "with walks but no at-bats, on-base is 1.0 and slugging and ops are nil" do
    totals = BattingLine.totals([ line(ab: 0, hits: 0, walks: 2) ])

    assert_in_delta 1.0, totals.on_base_percentage, 0.0001
    assert_nil totals.slugging_percentage
    assert_nil totals.ops
  end

  test "with no plate appearances at all, every rate is nil" do
    totals = BattingLine.totals([])

    assert_nil totals.average
    assert_nil totals.on_base_percentage
    assert_nil totals.slugging_percentage
    assert_nil totals.ops
  end
end
