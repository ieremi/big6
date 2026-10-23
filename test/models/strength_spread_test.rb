require "test_helper"

class StrengthSpreadTest < ActiveSupport::TestCase
  test "the variance is the mean of the squares of the distances from the mean" do
    assert_in_delta 2 / 3.0, StrengthSpread.variance([ 1.0, 2.0, 3.0 ]), 1e-9
    assert_equal 0.0, StrengthSpread.variance([ 0.5, 0.5 ])
  end

  test "a season counts only with all of its last ten seasons played" do
    Game.delete_all
    alpha, beta = universities(:one), universities(:two)
    seasons = (2010..2015).flat_map { |year| %w[spring autumn].map { |term| Season.find_or_create_by!(year: year, term: term) } }
    play = ->(season) { Game.create!(season: season, team0: alpha, team1: beta, played_on: Date.new(season.year, season.term == "spring" ? 5 : 10, 1), game_number: 1, team0_score: 1, team1_score: 0, game_status: "試合終了") }
    seasons.each(&play)
    current = seasons.last # 2015 autumn: 2011 spring to 2015 spring before it

    assert TeamStrength.new(current).full_history?

    Game.where(season: seasons[2]).delete_all # 2011 spring, one of the ten
    assert_not TeamStrength.new(current).full_history?
  end
end
