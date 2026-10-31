require "test_helper"

class LeagueOfficialScoreboardTest < ActiveSupport::TestCase
  def scoreboard(detail)
    LeagueOfficialScoreboard.new(Game.new(league_official_data: detail))
  end

  test "gives the finish time and the length once the page shows a whole game" do
    board = scoreboard("startTime" => "13:30", "finishTime" => "16:02", "runsTop" => %w[0 1 0 0 2 0 0 0 0].map(&:to_i), "runsBottom" => [ 0 ] * 9)

    assert_equal "16:02", board.finished_at
    assert_equal "2時間32分", board.duration
  end

  test "leaves out a finish time the page gives while the game is in its early innings, as on 2026-10-31" do
    board = scoreboard("startTime" => "13:00", "finishTime" => "13:03", "runsTop" => [ 0, 0, 0 ] + [ nil ] * 6, "runsBottom" => [ 1, 0 ] + [ nil ] * 7)

    assert_nil board.finished_at
    assert_nil board.duration
    assert_equal "13:00", board.started_at
  end

  test "has no finish time with no box score at all" do
    assert_nil scoreboard(nil).finished_at
  end
end
