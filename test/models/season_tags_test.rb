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

  # A card each week of 2012 spring, its games' scores [team0, team1] from team0's side.
  def card(team0, team1, saturday, *scores)
    scores.each_with_index do |(score0, score1), i|
      Game.create!(season: @season, team0: team0, team1: team1, played_on: saturday + i, game_number: i + 1,
        team0_score: score0, team1_score: score1, game_status: "試合終了")
    end
  end

  test "a season won outright is tagged with the week its title was decided" do
    gamma = University.create!(name: "Gamma University", short_name: "Gamma", slug: "gamma", position: 3)
    delta = University.create!(name: "Delta University", short_name: "Delta", slug: "delta", position: 4)
    card(@beta, gamma, Date.new(2012, 5, 5), [ 1, 0 ], [ 1, 0 ]) # beta 2-0
    card(@beta, delta, Date.new(2012, 5, 12), [ 1, 0 ], [ 0, 1 ], [ 1, 0 ]) # beta 2-1
    card(gamma, delta, Date.new(2012, 5, 19), [ 1, 0 ], [ 1, 0 ])
    card(@alpha, @beta, Date.new(2012, 5, 26), [ 1, 0 ], [ 1, 0 ])
    card(@alpha, gamma, Date.new(2012, 6, 2), [ 1, 0 ], [ 1, 0 ]) # alpha 2 points at 4-0: beta, on 2 at 4-3, can't catch it
    card(@alpha, delta, Date.new(2012, 6, 9), [ 0, 1 ], [ 0, 1 ])

    assert_equal "2012-06-03", TitleRace.clinching_game(@season).played_on.to_s
    assert_includes labels, "第5週で優勝"
    assert_equal 1, labels.count { |label| label.end_with?("週で優勝") }
  end

  test "a title decided in a game between 早大 and 慶大 is tagged as decided in the 早慶戦" do
    waseda = University.create!(name: "早稲田大学", short_name: "早大", slug: "waseda", position: 11)
    keio = University.create!(name: "慶應義塾大学", short_name: "慶大", slug: "keio", position: 12)
    card(waseda, @beta, Date.new(2012, 5, 5), [ 1, 0 ], [ 1, 0 ])
    card(keio, @beta, Date.new(2012, 5, 12), [ 1, 0 ], [ 1, 0 ])
    card(keio, waseda, Date.new(2012, 5, 19), [ 1, 0 ], [ 2, 1 ]) # 1 point each before it: the card decides

    assert_includes labels, SeasonTags::CLINCHED_IN_SOKEISEN
  end

  test "a title decided in another card isn't" do
    card(@alpha, @beta, Date.new(2012, 5, 5), [ 1, 0 ], [ 1, 0 ])

    assert_not_includes labels, SeasonTags::CLINCHED_IN_SOKEISEN
  end

  test "a 3回戦 that was held still counts" do
    add_games(held: 4)
    Game.create!(season: @season, team0: @alpha, team1: @beta, played_on: "2012-07-01", game_number: 3, team0_score: 1, team1_score: 0, game_status: "試合終了")

    assert_not_includes labels, SeasonTags::NO_ROUND_3
  end
end
