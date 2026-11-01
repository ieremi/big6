require "test_helper"

class TeamStatsTest < ActiveSupport::TestCase
  setup do
    Game.delete_all
    @alpha, @beta = universities(:one), universities(:two)
    @season = seasons(:one)
    @batter = Player.create!(scorebook_id: 1, university: @alpha, name: "打者", enter_year: 2023, role: "選手")
    @pitcher = Player.create!(scorebook_id: 2, university: @alpha, name: "投手", enter_year: 2023, role: "選手")
  end

  def game(day, **attributes)
    Game.create!({ season: @season, team0: @alpha, team1: @beta, played_on: Date.new(2026, 5, day), game_number: day,
      team0_score: 3, team1_score: 1, game_status: "試合終了" }.merge(attributes))
  end

  def lines(game, ab:, hits:, outs:, earned_runs:)
    BattingLine.create!(game:, player: @batter, university: @alpha, ab:, hits:)
    PitchingLine.create!(game:, player: @pitcher, university: @alpha, outs:, earned_runs:)
  end

  test "a team's batting average and ERA are worked out from its lines' sums over the season" do
    lines(game(1), ab: 30, hits: 9, outs: 27, earned_runs: 2)
    lines(game(2), ab: 34, hits: 7, outs: 24, earned_runs: 4)

    row = TeamStats.new(@season).rows.find { |each| each.university == @alpha }

    assert_equal 2, row.games
    assert_in_delta 16.0 / 64, row.batting.average
    assert_in_delta 6 * 27.0 / 51, row.pitching.era
  end

  test "a playoff's lines are left out, and a team with no lines has no row" do
    lines(game(1), ab: 30, hits: 9, outs: 27, earned_runs: 2)
    lines(game(2, counted_in_stats: false, playoff: "優勝決定戦"), ab: 30, hits: 30, outs: 3, earned_runs: 9)

    rows = TeamStats.new(@season).rows

    assert_equal [ @alpha ], rows.map(&:university)
    assert_equal [ 1, 9 ], [ rows.first.games, rows.first.batting.hits ]
  end
end
