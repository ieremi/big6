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

  test "teams level on both 勝ち点 and 勝率 share a place, and the next place skips ahead" do
    gamma = University.create!(name: "Gamma University", short_name: "Gamma", slug: "gamma", position: 3)
    game(1, 5, 2)
    game(2, 2, 5) # alpha and beta 1勝1敗: level

    standings = Standings.new(seasons(:one))

    assert_equal [ 1, 1, 3 ], [ @alpha, @beta, gamma ].map { |university| standings.row_for(university).rank }
  end

  test "a team ahead on 勝率 alone is a place ahead" do
    game(1, 5, 2)

    standings = Standings.new(seasons(:one))

    assert_equal [ 1, 2 ], [ standings.row_for(@alpha).rank, standings.row_for(@beta).rank ]
  end
  # ---- 2020 and 2021: points, a win 1 and a draw 0.5

  def points_season_game(day, team0, team1, team0_score, team1_score)
    @points_season ||= Season.create!(year: 2021, term: "autumn")
    Game.create!(season: @points_season, team0:, team1:, played_on: Date.new(2021, 10, day), game_number: day.odd? ? 1 : 2,
      team0_score:, team1_score:, game_status: "試合終了")
  end

  test "in 2021 a team's points are its wins and half its draws, and they rank it, though no card was won twice" do
    points_season_game(1, @alpha, @beta, 3, 3)
    points_season_game(2, @alpha, @beta, 2, 1)

    standings = Standings.new(@points_season)

    assert_equal [ 1.5, 0.5 ], [ standings.row_for(@alpha).points, standings.row_for(@beta).points ]
    assert_equal [ @alpha, @beta ], standings.rows.map(&:university)
    assert_equal [ 1, 2 ], standings.rows.map(&:rank)
    assert_equal @alpha, SeasonChampion.of(@points_season)
  end

  test "in 2021 two teams level on points and 勝率 are told apart by the games between them" do
    gamma = University.create!(name: "Gamma University", short_name: "Gamma", slug: "gamma", position: 3)
    points_season_game(1, @alpha, @beta, 1, 2)  # beta over alpha
    points_season_game(3, @alpha, gamma, 5, 0)  # alpha over gamma
    points_season_game(5, @beta, gamma, 0, 4)   # gamma over beta: alpha and beta are 1勝1敗, 1 point each, and gamma too

    three = Standings.new(@points_season)
    assert_equal [ 1, 1, 1 ], three.rows.map(&:rank) # three level: the games between them don't decide

    points_season_game(7, gamma, @alpha, 0, 0) # alpha and gamma 1.5 points, alpha having beaten gamma

    standings = Standings.new(@points_season)
    assert_equal [ @alpha, gamma, @beta ], standings.rows.map(&:university)
    assert_equal [ 1, 2, 3 ], standings.rows.map(&:rank)
  end
end
