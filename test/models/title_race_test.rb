require "test_helper"

class TitleRaceTest < ActiveSupport::TestCase
  setup do
    Game.delete_all
    @season = seasons(:one)
    @alpha = universities(:one)
    @beta = universities(:two)
    @gamma = University.create!(name: "Gamma University", short_name: "Gamma", slug: "gamma", position: 3)
  end

  def game(team0, team1, day, number, score: nil)
    Game.create!(season: @season, team0: team0, team1: team1, played_on: Date.new(2026, 5, day), game_number: number,
      team0_score: score&.first, team1_score: score&.last, game_status: score ? "試合終了" : "試合前")
  end

  # Week 1: alpha takes its card with beta 2-0 (1 point). Weeks 2 and 3, alpha v
  # gamma and beta v gamma, still to play.
  def three_teams
    game(@alpha, @beta, 2, 1, score: [ 3, 1 ])
    game(@beta, @alpha, 3, 2, score: [ 0, 2 ])
    game(@alpha, @gamma, 9, 1)
    game(@gamma, @alpha, 10, 2)
    game(@beta, @gamma, 16, 1)
    game(@gamma, @beta, 17, 2)
  end

  def names(race, results)
    race.champions_for(results).map(&:slug)
  end

  test "gives the champion for every way the open cards can end, with a playoff where teams are level" do
    three_teams

    race = TitleRace.new(@season)

    assert race.applicable?
    assert_equal [ "②Alpha-Gamma", "③Beta-Gamma" ], race.cards.map(&:label)
    assert_equal [ [ 2, 0 ], [ 2, 1 ], [ 1, 2 ], [ 0, 2 ] ], race.cards.first.results
    assert_equal [ "②Alpha-Gamma" ], race.row_cards.map(&:label)
    assert_equal [ "③Beta-Gamma" ], race.column_cards.map(&:label)

    assert_equal %w[alpha], names(race, [ [ 2, 1 ], [ 0, 2 ] ]) # alpha's second card: 2 points
    assert_equal %w[gamma], names(race, [ [ 1, 2 ], [ 0, 2 ] ]) # gamma's two cards
    assert_equal %w[alpha], names(race, [ [ 1, 2 ], [ 2, 0 ] ]) # 1 point each, alpha on 3-2 ahead
    assert_equal %w[gamma], names(race, [ [ 0, 2 ], [ 2, 1 ] ]) # 1 point each, gamma on 3-2 ahead
    assert_equal %w[alpha beta gamma], names(race, [ [ 0, 2 ], [ 2, 0 ] ]) # all 1 point and 2-2: a playoff
  end

  test "each university's chance, every game an even chance and a playoff an even split" do
    three_teams

    chances = TitleRace.new(@season).chances.transform_keys(&:slug)

    assert_equal %w[alpha gamma beta], chances.keys
    assert_in_delta 31.0 / 48, chances["alpha"], 1e-9
    assert_in_delta 16.0 / 48, chances["gamma"], 1e-9
    assert_in_delta 1.0 / 48, chances["beta"], 1e-9
  end

  test "a card half played can only end the ways left to it" do
    three_teams
    Game.find_by(team0: @alpha, team1: @gamma).update!(team0_score: 4, team1_score: 2, game_status: "試合終了")

    assert_equal [ [ 2, 0 ], [ 2, 1 ], [ 1, 2 ] ], TitleRace.new(@season).cards.first.results
  end

  test "a card that never changes the champion is left out, and once none can, the champion is settled" do
    three_teams
    Game.where(team0: @alpha, team1: @gamma).update_all(team0_score: 4, team1_score: 2, game_status: "試合終了")
    Game.where(team0: @gamma, team1: @alpha).update_all(team0_score: 1, team1_score: 5, game_status: "試合終了") # alpha: 2 points

    race = TitleRace.new(@season)

    assert race.applicable? # beta v gamma is still to play
    assert_empty race.cards
    assert_equal [ @alpha ], race.settled
    assert_equal({ @alpha => 1.0 }, race.chances)
  end

  test "isn't for a season over, nor for the 2020 formats" do
    three_teams
    Game.where(played_on: Date.new(2026, 5, 9)..).delete_all

    assert_not TitleRace.new(@season).applicable?
    assert_not TitleRace.new(Season.create!(year: 2020, term: "autumn")).applicable?
  end
end
