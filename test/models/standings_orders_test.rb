require "test_helper"

class StandingsOrdersTest < ActiveSupport::TestCase
  SLUGS = %w[a b c d e f].freeze

  setup do
    Game.delete_all
    University.delete_all
    @universities = SLUGS.each_with_index.to_h do |slug, index|
      [ slug, University.create!(name: slug, short_name: slug.upcase, slug: slug, position: index + 1) ]
    end
  end

  # A season of fifteen two-game cards: each pair's winner is the university
  # earlier in ranking (a list of slugs), so the standings follow it.
  def play_season(year, term, ranking, playoff: nil, unplayed: false)
    season = Season.create!(year: year, term: term)
    day = Date.new(year, term == "spring" ? 4 : 9, 10)
    ranking.combination(2).each do |winner, loser|
      2.times do |round|
        Game.create!(season: season, team0: @universities[winner], team1: @universities[loser], played_on: day, game_number: round + 1,
          team0_score: 3, team1_score: 1, game_status: unplayed && round == 1 ? "試合前" : "試合終了")
        day += 1
      end
    end
    if playoff
      winner, loser = playoff
      Game.create!(season: season, team0: @universities[winner], team1: @universities[loser], played_on: day, game_number: 1,
        team0_score: 2, team1_score: 1, game_status: "試合終了", counted_in_stats: false)
    end
    season
  end

  test "groups the seasons that ended in the same order" do
    first = play_season(1990, "spring", %w[a b c d e f])
    second = play_season(2010, "autumn", %w[a b c d e f])
    other = play_season(2000, "spring", %w[b a c d e f])

    orders = StandingsOrders.new.orders

    assert_equal [ [ second, first ], [ other ] ], orders.map(&:seasons)
    assert_equal "ABCDEF", orders.first.label
    assert_equal "a-b-c-d-e-f", orders.first.key
    assert_equal [ 123456, 213456 ], orders.map(&:sort_value)
    assert_equal [ 20102, 20001 ], orders.map(&:latest_season_value)
  end

  test "shows universities level on 勝ち点 and 勝率 as tied, and puts a playoff's winner first" do
    season = play_season(1990, "spring", %w[a b c d e f])
    # a and b split their card 1–1: both 4 勝ち点, 9–1.
    Game.where(season: season, team0: @universities["a"], team1: @universities["b"], game_number: 2).update_all(team0_score: 1, team1_score: 3)
    assert_equal "A=BCDEF", StandingsOrders.new.orders.first.label

    Game.create!(season: season, team0: @universities["b"], team1: @universities["a"], played_on: Date.new(1990, 6, 1), game_number: 1,
      team0_score: 2, team1_score: 1, game_status: "試合終了", counted_in_stats: false)
    assert_equal "BACDEF", StandingsOrders.new.orders.first.label
  end

  test "leaves out seasons not over, and those before 1950" do
    play_season(2026, "autumn", %w[a b c d e f], unplayed: true)
    play_season(1949, "spring", %w[a b c d e f])

    assert_empty StandingsOrders.new.orders
  end

  test "ranks 2020 and 2021 by points, a draw half a win" do
    season = play_season(2020, "autumn", %w[a b c d e f])
    # a and b's card: a draw, then a win for b. a 8.5 points (8–1–1), b 9.5 (9–0–1).
    Game.where(season: season, team0: @universities["a"], team1: @universities["b"], game_number: 1).update_all(team0_score: 2, team1_score: 2)
    Game.where(season: season, team0: @universities["a"], team1: @universities["b"], game_number: 2).update_all(team0_score: 1, team1_score: 3)

    assert_equal "BACDEF", StandingsOrders.new.orders.first.label
  end

  test "puts two universities level on points and 勝率 in 2020 and 2021 in the order of the games between them" do
    season = play_season(2020, "autumn", %w[a b c d e f])
    # c and d split their card 1–1: both 7–3, level, and even between them.
    Game.where(season: season, team0: @universities["c"], team1: @universities["d"], game_number: 2).update_all(team0_score: 1, team1_score: 3)
    assert_equal "ABC=DEF", StandingsOrders.new.orders.first.label

    # 2020 spring, one game a card: a loses to e and e to f, so e and f are
    # both 1–4, f having beaten e, and f goes above e.
    spring = play_season(2020, "spring", %w[a b c d e f])
    Game.where(season: spring, game_number: 2).delete_all
    Game.where(season: spring, team0: @universities["a"], team1: @universities["e"]).update_all(team0_score: 0, team1_score: 1)
    Game.where(season: spring, team0: @universities["e"], team1: @universities["f"]).update_all(team0_score: 0, team1_score: 1)
    assert_equal "ABCDFE", StandingsOrders.new.orders.find { |order| order.seasons.include?(spring) }.label
  end
end
