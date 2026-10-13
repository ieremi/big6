require "test_helper"

class SeasonChampionTest < ActiveSupport::TestCase
  setup do
    Game.delete_all
    @alpha = universities(:one)
    @beta = universities(:two)
  end

  def play(season, team0, team1, score0, score1, on, round, **attributes)
    Game.create!({ season: season, team0: team0, team1: team1, team0_score: score0, team1_score: score1,
      played_on: on, game_number: round, game_status: "試合終了" }.merge(attributes))
  end

  test "is the top of the standings, or the playoff's winner" do
    spring = seasons(:one)
    play(spring, @alpha, @beta, 2, 0, "2026-04-11", 1)
    play(spring, @beta, @alpha, 0, 1, "2026-04-12", 2)
    assert_equal @alpha, SeasonChampion.of(spring)

    play(spring, @beta, @alpha, 3, 1, "2026-06-01", 1, counted_in_stats: false)
    assert_equal @beta, SeasonChampion.of(spring)
  end

  test "is none for a season not ranked by 勝ち点" do
    season = Season.create!(year: 1949, term: "spring")
    play(season, @alpha, @beta, 2, 0, "1949-04-11", 1)
    play(season, @beta, @alpha, 0, 1, "1949-04-12", 2)

    assert_nil SeasonChampion.of(season)
  end

  test "counts the seasons in a row won, through the previous seasons" do
    spring = seasons(:one)
    autumn_before = Season.create!(year: 2025, term: "autumn")
    spring_before = Season.create!(year: 2025, term: "spring")
    play(spring_before, @beta, @alpha, 2, 0, "2025-04-12", 1)
    play(spring_before, @alpha, @beta, 0, 1, "2025-04-13", 2)
    play(autumn_before, @alpha, @beta, 2, 0, "2025-09-13", 1)
    play(autumn_before, @beta, @alpha, 0, 1, "2025-09-14", 2)

    assert_equal 2, SeasonChampion.streak(spring, @alpha)
    assert_equal 1, SeasonChampion.streak(spring, @beta)
  end
end
