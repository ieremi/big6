require "test_helper"

class StandingsTest < ActiveSupport::TestCase
  setup do
    @alpha = universities(:one)
    @beta = universities(:two)
    Game.delete_all
  end

  def game(number, team0_score, team1_score, **attributes)
    Game.create!({ season: seasons(:one), team0: @alpha, team1: @beta, played_on: Date.new(2026, 5, 1) + number, game_number: number,
      team0_score: team0_score, team1_score: team1_score, game_status: "試合終了" }.merge(attributes))
  end

  test "each team's runs scored and allowed are summed over its games with a score, a draw included" do
    game(1, 5, 2)
    game(2, 1, 3)
    game(3, 4, 4) # 引き分け
    game(4, nil, nil, game_status: "中止")
    game(5, nil, nil, game_status: "試合前")

    standings = Standings.new(seasons(:one))

    assert_equal [ 10, 9 ], standings.row_for(@alpha).to_h.values_at(:runs_scored, :runs_allowed)
    assert_equal [ 9, 10 ], standings.row_for(@beta).to_h.values_at(:runs_scored, :runs_allowed)
  end

  test "a team with no games has scored and allowed nothing" do
    row = Standings.new(seasons(:one)).row_for(@alpha)

    assert_equal [ 0, 0 ], [ row.runs_scored, row.runs_allowed ]
  end
end
