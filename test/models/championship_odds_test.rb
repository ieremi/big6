require "test_helper"

class ChampionshipOddsTest < ActiveSupport::TestCase
  # Three universities: Alpha has taken its card with Beta 2-0, and the cards
  # Alpha-Gamma and Beta-Gamma are still to play. Worked out by hand:
  #
  # Before Alpha's first game with Gamma, Alpha takes the title if it wins
  # that card (1/2), and also on 勝率 in 7 of the 16 ways Gamma can win it and
  # lose to Beta (one of them a three-way tie on 勝ち点 and 勝率, a third
  # each): 31/48. Gamma, by beating Alpha and Beta (1/4) or on 勝率 (1/16) and
  # the tie (1/48): 1/3. Beta only through the tie: 1/48.
  #
  # Once Alpha has won that game: Alpha 3/4 by taking the card, plus 1/8 on
  # 勝率 when Gamma takes it 2-1 and loses to Beta: 7/8. Gamma 1/8. Beta none.
  setup do
    Game.delete_all
    @season = seasons(:one)
    @alpha = universities(:one)
    @beta = universities(:two)
    @gamma = University.create!(name: "Gamma University", short_name: "Gamma", slug: "gamma", position: 3)
    play(@alpha, @beta, 3, 1, on: Date.new(2026, 4, 11), round: 1)
    play(@beta, @alpha, 0, 2, on: Date.new(2026, 4, 12), round: 2)
    Game.create!(season: @season, team0: @beta, team1: @gamma, played_on: Date.new(2026, 5, 2), game_number: 1)
  end

  def play(team0, team1, score0, score1, on:, round:)
    Game.create!(season: @season, team0: team0, team1: team1, team0_score: score0, team1_score: score1,
      played_on: on, game_number: round, game_status: "試合終了")
  end

  test "works out each side's chance of the title just before and just after a game" do
    game = play(@alpha, @gamma, 5, 4, on: Date.new(2026, 4, 25), round: 1)

    odds = ChampionshipOdds.around(game)

    assert_in_delta 31.0 / 48, odds[:before][@alpha.id]
    assert_in_delta 1.0 / 48, odds[:before][@beta.id]
    assert_in_delta 1.0 / 3, odds[:before][@gamma.id]
    assert_in_delta 7.0 / 8, odds[:after][@alpha.id]
    assert_in_delta 0.0, odds[:after][@beta.id]
    assert_in_delta 1.0 / 8, odds[:after][@gamma.id]
  end

  test "counts the other games of the same day on both sides" do
    game = play(@alpha, @gamma, 5, 4, on: Date.new(2026, 4, 25), round: 1)
    play(@beta, @gamma, 1, 0, on: Date.new(2026, 4, 25), round: 1)

    odds = ChampionshipOdds.around(game)

    assert_in_delta odds[:before].values.sum, 1.0
    assert_in_delta odds[:after].values.sum, 1.0
    # Beta's win that day is in the odds before Alpha's game too.
    assert odds[:before][@beta.id] > 1.0 / 48
  end

  test "isn't worked out for the 2020 formats" do
    season = Season.create!(year: 2020, term: "autumn")
    game = Game.create!(season: season, team0: @alpha, team1: @gamma, team0_score: 1, team1_score: 0,
      played_on: Date.new(2020, 9, 19), game_number: 1, game_status: "試合終了")

    assert_nil ChampionshipOdds.around(game)
  end

  test "isn't worked out for a playoff" do
    game = play(@alpha, @gamma, 5, 4, on: Date.new(2026, 4, 25), round: 1)
    game.update!(counted_in_stats: false)

    assert_nil ChampionshipOdds.around(game)
  end

  test "isn't worked out for a season whose cards aren't best of three" do
    game = play(@alpha, @gamma, 5, 4, on: Date.new(2026, 4, 25), round: 1)
    play(@alpha, @beta, 1, 0, on: Date.new(2026, 4, 13), round: 3)

    assert_nil ChampionshipOdds.around(game)
  end
end
