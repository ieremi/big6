require "test_helper"

class SeasonTagsTest < ActiveSupport::TestCase
  setup do
    @alpha = universities(:one)
    @beta = universities(:two)
    @season = Season.create!(year: 2012, term: "spring")
  end

  # Games in a season: `held` finished ones, then `cancelled` cancelled ones.
  def add_games(held:, cancelled: 0)
    held.times { |i| Game.create!(season: @season, team0: @alpha, team1: @beta, played_on: Date.new(2012, 1, 1) + i, game_number: 1 + i % 2, team0_score: 2, team1_score: 1, game_status: "試合終了") }
    cancelled.times { |i| Game.create!(season: @season, team0: @alpha, team1: @beta, played_on: Date.new(2012, 6, 1) + i, game_number: 1 + i % 2, game_status: "中止") }
  end

  def labels
    SeasonTags.new(@season).tags.map(&:label)
  end

  test "40試合超え counts the games held, not the cancelled ones" do
    add_games(held: 39, cancelled: 2)

    assert_not_includes labels, SeasonTags::MANY_GAMES
  end

  test "40試合超え is given to a season of 40 games held" do
    add_games(held: 40)

    assert_includes labels, SeasonTags::MANY_GAMES
  end

  test "a cancelled 3回戦 is not a 3回戦 that was played" do
    add_games(held: 4)
    Game.create!(season: @season, team0: @alpha, team1: @beta, played_on: "2012-07-01", game_number: 3, game_status: "中止")

    assert_includes labels, SeasonTags::NO_ROUND_3
  end

  test "a 3回戦 that was held still counts" do
    add_games(held: 4)
    Game.create!(season: @season, team0: @alpha, team1: @beta, played_on: "2012-07-01", game_number: 3, team0_score: 1, team1_score: 0, game_status: "試合終了")

    assert_not_includes labels, SeasonTags::NO_ROUND_3
  end
end
