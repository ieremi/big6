require "test_helper"

class ManagerTenureTest < ActiveSupport::TestCase
  setup do
    Game.delete_all
    @alpha, @beta = universities(:one), universities(:two)
  end

  # A card of two games, the first university winning the given number of them.
  def card(year, term, wins)
    season = Season.find_or_create_by!(year:, term:)
    day = Date.new(year, term == "spring" ? 4 : 9, 10)
    2.times.map do |n|
      won = n < wins
      Game.create!(season:, team0: @alpha, team1: @beta, played_on: day + n, game_number: n + 1,
        team0_score: won ? 3 : 1, team1_score: won ? 1 : 3, game_status: "試合終了")
    end
  end

  test "counts the record against each opponent and the cards, from the first season on" do
    card(2018, "autumn", 2) # before the manager
    card(2019, "spring", 2)
    card(2019, "autumn", 1)

    opponent = ManagerTenure.new(@alpha, from: [ 2019, "spring" ]).by_opponent.sole

    assert_equal [ @beta, 3, 1, 0, 1, 0 ], [ opponent.university, opponent.wins, opponent.losses, opponent.draws, opponent.cards_won, opponent.cards_lost ]
  end

  test "finds the titles and the longest run of them" do
    card(2019, "spring", 2)
    card(2019, "autumn", 2)
    card(2020, "autumn", 0)
    tenure = ManagerTenure.new(@alpha, from: [ 2019, "spring" ])
    champion = ->(season) { season.year == 2020 ? @beta : @alpha }

    stub_method(SeasonChampion, :of, champion) do
      assert_equal %w[2019-spring 2019-autumn], tenure.titles.map { |season| "#{season.year}-#{season.term}" }
      assert_equal 2, tenure.longest_run.size
    end
  end

  test "each year's leaders: batters by average among those reaching the minimum, pitchers by innings" do
    games = card(2019, "spring", 2) # 2 games: a minimum of 6 plate appearances
    player = ->(id) { Player.create!(scorebook_id: id, university: @alpha, name: "選手#{id}", enter_year: 2018, role: "選手") }
    regular, short, pitcher = player.(1), player.(2), player.(3)
    games.each do |game|
      BattingLine.create!(game:, player: regular, university: @alpha, pa: 4, ab: 4, hits: 2)
      BattingLine.create!(game:, player: short, university: @alpha, pa: 1, ab: 1, hits: 1) # 1.000, but 2 plate appearances
      PitchingLine.create!(game:, player: pitcher, university: @alpha, outs: 27, earned_runs: 1, wins: 1)
    end

    leaders = ManagerTenure.new(@alpha, from: [ 2019, "spring" ]).leaders.sole

    assert_equal 2019, leaders.year
    assert_equal [ regular ], leaders.batters.map(&:player)
    assert_equal [ [ pitcher, 54, 2 ] ], leaders.pitchers.map { |leader| [ leader.player, leader.totals.outs, leader.totals.wins ] }
  end
end
