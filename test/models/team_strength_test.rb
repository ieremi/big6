require "test_helper"

class TeamStrengthTest < ActiveSupport::TestCase
  setup do
    Game.delete_all
    @alpha = universities(:one)
    @beta = universities(:two)
    @season = seasons(:two) # 2026 autumn
    @earlier = seasons(:one) # 2026 spring
  end

  def game(season, day, score, team0: @alpha, team1: @beta, **attributes)
    Game.create!({ season: season, team0: team0, team1: team1, played_on: day, game_number: 1,
      team0_score: score&.first, team1_score: score&.last, game_status: score ? "試合終了" : "試合前" }.merge(attributes))
  end

  # { slug => chance, rounded } at each point.
  def chances(strength = TeamStrength.new(@season))
    strength.points.map { |point, by_university| [ point&.key, by_university.to_h { |university, chance| [ university.slug, chance.round(3) ] } ] }
  end

  test "starts from the last seasons' level, and moves with this season's results" do
    3.times { |i| game(@earlier, Date.new(2026, 5, 2 + i), [ 3, 1 ]) } # alpha won all three in spring
    game(@season, Date.new(2026, 9, 12), [ 0, 2 ]) # then lost the autumn's first
    game(@season, Date.new(2026, 9, 13), nil)

    points = chances
    assert_equal [ nil, "2026-09-12-alpha-beta" ], points.map(&:first) # the opening day, then the game ended
    before, after = points.map(&:last)
    assert_operator before["alpha"], :>, 0.5
    assert_operator after["alpha"], :<, before["alpha"]
    assert_in_delta 1.0, before["alpha"] + before["beta"], 0.001 # two sides: each against their mean
  end

  test "the last seasons' level is eased towards .500 by a few games' worth" do
    game(@earlier, Date.new(2026, 5, 2), [ 3, 1 ])
    game(@season, Date.new(2026, 9, 12), [ 1, 1 ]) # a draw: a point, but no change

    (_, before), (_, after) = chances
    past_gap = TeamStrength::PAST_WEIGHT * (TeamStrength.rate([ 1, 0 ], TeamStrength::PAST_PRIOR) - TeamStrength.rate([ 0, 1 ], TeamStrength::PAST_PRIOR))
    assert_in_delta 1 / (1 + Math.exp(-past_gap / 2)), before["alpha"], 0.001
    assert_equal before, after
  end

  test "nothing for a season with no results, or one from printed sources" do
    game(@season, Date.new(2026, 9, 12), nil)
    assert_empty chances.drop(1)

    game(@season, Date.new(2026, 9, 13), [ 1, 0 ], source_citation: "立教大学野球部史")
    assert_not TeamStrength.new(@season).applicable?
    assert_empty chances
  end
end
