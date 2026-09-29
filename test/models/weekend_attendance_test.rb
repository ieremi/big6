require "test_helper"

# Attendance counted over the weekend games only (平日の試合をのぞく): Game#weekend?,
# and the averages and totals of Matchup and Standings with weekends_only.
class WeekendAttendanceTest < ActiveSupport::TestCase
  setup do
    @alpha = universities(:one)
    @beta = universities(:two)
    Game.delete_all
    # Saturday and Sunday draw crowds; the Monday game (a replay) doesn't.
    { "2026-05-02" => 20_000, "2026-05-03" => 10_000, "2026-05-04" => 3_000 }.each_with_index do |(date, attendance), index|
      Game.create!(season: seasons(:one), team0: @alpha, team1: @beta, played_on: date, game_number: index + 1,
        team0_score: 2, team1_score: 1, game_status: "試合終了", attendance: attendance)
    end
  end

  test "a game on a Saturday or a Sunday is a weekend game, whatever the holidays" do
    assert_equal [ true, true, false ], Game.order(:played_on).map(&:weekend?)
  end

  test "a matchup's attendance can leave the weekday games out" do
    matchup = Matchup.new(@alpha, @beta)

    assert_equal [ 11_000, 33_000 ], [ matchup.average_attendance, matchup.total_attendance ]
    assert_equal [ 15_000, 30_000 ], [ matchup.average_attendance(weekends_only: true), matchup.total_attendance(weekends_only: true) ]
  end

  test "the standings' attendance can leave the weekday games out" do
    row = Standings.new(seasons(:one)).row_for(@alpha)

    assert_equal [ 11_000, 33_000 ], [ row.average_attendance, row.total_attendance ]
    assert_equal [ 15_000, 30_000 ], [ row.average_attendance(weekends_only: true), row.total_attendance(weekends_only: true) ]
  end

  test "with only weekday games, there is no weekend average" do
    Game.where(played_on: %w[2026-05-02 2026-05-03]).delete_all

    assert_nil Matchup.new(@alpha, @beta).average_attendance(weekends_only: true)
    assert_nil Standings.new(seasons(:one)).row_for(@alpha).average_attendance(weekends_only: true)
  end
end
