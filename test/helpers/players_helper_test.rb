require "test_helper"

class PlayersHelperTest < ActionView::TestCase
  test "batting_average_label drops the leading zero" do
    assert_equal ".257", batting_average_label(0.2571)
    assert_equal ".000", batting_average_label(0.0)
    assert_equal ".333", batting_average_label(1 / 3.0)
  end

  test "batting_average_label keeps 1.000 and shows dashes without an at-bat" do
    assert_equal "1.000", batting_average_label(1.0)
    assert_equal "---", batting_average_label(nil)
  end

  test "innings_label shows partial innings as thirds" do
    assert_equal "3", innings_label(9)
    assert_equal "3 1/3", innings_label(10)
    assert_equal "3 2/3", innings_label(11)
    assert_equal "0 2/3", innings_label(2)
    assert_equal "0", innings_label(0)
  end

  test "era_label uses two decimals and dashes when undefined" do
    assert_equal "2.44", era_label(2.4444)
    assert_equal "0.00", era_label(0.0)
    assert_equal "---", era_label(nil)
  end

  test "opponent_name is the other team of the game" do
    alpha = universities(:one)
    beta = universities(:two)
    game = Game.create!(season: seasons(:one), team0: alpha, team1: beta, played_on: "2026-05-02", game_number: 1)

    assert_equal beta.short_name, opponent_name(BattingLine.new(game: game, university: alpha))
    assert_equal alpha.short_name, opponent_name(BattingLine.new(game: game, university: beta))
  end

  test "ops_label is written like a batting average" do
    assert_equal ".763", ops_label(0.7631)
    assert_equal "1.024", ops_label(1.0243)
    assert_equal "---", ops_label(nil)
  end
end
