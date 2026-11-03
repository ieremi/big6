require "test_helper"

class BattingTitleRaceTest < ActiveSupport::TestCase
  setup do
    Game.delete_all
    @alpha, @beta = universities(:one), universities(:two)
    @gamma = University.create!(name: "Gamma University", short_name: "Gamma", slug: "gamma", position: 3)
    @season = Season.create!(year: 2030, term: "spring")
    # alpha has played its two games (with beta); beta and gamma have their card still to play.
    @played = (1..2).map do |n|
      Game.create!(season: @season, team0: @alpha, team1: @beta, played_on: Date.new(2030, 4, n), game_number: n,
        team0_score: 3, team1_score: 1, game_status: "試合終了")
    end
    (1..2).each do |n|
      Game.create!(season: @season, team0: @beta, team1: @gamma, played_on: Date.new(2030, 4, 10 + n), game_number: n, game_status: "試合前")
    end
    @leader = batter(1, @alpha, pa: 8, ab: 8, hits: 4) # .500
    @rival = batter(2, @beta, pa: 9, ab: 8, hits: 3) # .375, 4 at-bats a game
    batter(3, @beta, pa: 1, ab: 1, hits: 1) # 1.000, far short of the minimum
  end

  # A batter with their lines split over the two games played.
  def batter(id, university, pa:, ab:, hits:)
    player = Player.create!(scorebook_id: id, university:, name: "打者#{id}", enter_year: 2030, role: "選手")
    @played.each_with_index do |game, index|
      share = ->(total) { index.zero? ? total - total / 2 : total / 2 }
      BattingLine.create!(game:, player:, university:, pa: share.(pa), ab: share.(ab), hits: share.(hits))
    end
    player
  end

  def race
    BattingTitleRace.new(@season, player: @leader)
  end

  test "a card yet to start may go to a 3回戦, and a university done has no games left" do
    assert_equal 2..3, race.games_left(@beta)
    assert_equal 0..0, race.games_left(@alpha)
  end

  test "a rival needs the hits that put them above the player at three decimals, at their own pace" do
    rival = race.rivals.sole

    assert_equal @rival, rival.player
    # 2 games, 8 at-bats: 5 hits make .500, level; 6 make .563. 3 games, 12 at-bats: 8 make .550.
    assert_equal [ [ 2, 8, 6 ], [ 3, 12, 8 ] ], rival.needs.map { |need| [ need.games, need.at_bats, need.hits ] }
    assert race.final?
  end

  test "a batter who wouldn't reach the minimum at their pace can't pass" do
    assert_not_includes race.rivals.map { |rival| rival.player.scorebook_id }, 3
  end

  test "the player's figure isn't final while a game played has no box score" do
    late = Game.create!(season: @season, team0: @gamma, team1: @alpha, played_on: Date.new(2030, 4, 5), game_number: 1,
      team0_score: 0, team1_score: 2, game_status: "試合終了")

    assert_equal [ late ], race.pending_games
    assert_not race.final?
  end

  test "a batter above the player with no games left has passed them for good" do
    above = batter(4, @alpha, pa: 8, ab: 8, hits: 5)

    assert_equal [ above ], race.passed_for_good.map(&:player)
  end
end
