require "test_helper"

class PlayerSummaryTest < ActiveSupport::TestCase
  setup do
    @alpha = universities(:one)
    Game.delete_all
  end

  def player(**attributes)
    Player.create!({ scorebook_id: 20246018, university: @alpha, name: "田中 優飛", name_kana: "タナカ ユウト", enter_year: 2024,
      role: "選手", position: "投手", high_school: "仙台育英" }.merge(attributes))
  end

  def summary(player)
    PlayerSummary.new(player, PlayerStats.new(player)).to_s
  end

  def game(day = "2026-04-11")
    Game.create!(season: seasons(:one), team0: @alpha, team1: universities(:two), played_on: day, game_number: 1, team0_score: 3, team1_score: 1, game_status: "試合終了")
  end

  # Every season from 2024 on has box scores, so no season of a 2024 entrant lacks them.
  def with_stats_everywhere(&block)
    stub_method(PlayerRanking, :seasons_without_stats, ->(_kind) { [] }, &block)
  end

  test "tells the player's university, position, entry and school, and their pitching" do
    pitcher = player
    PitchingLine.create!(game: game, player: pitcher, university: @alpha, outs: 27, earned_runs: 1, strikeouts: 9, wins: 1)

    with_stats_everywhere do
      assert_equal "田中 優飛（タナカ ユウト）は、東京六大学野球・#{@alpha.name}の投手。2024年入学、仙台育英出身。" \
        "リーグ戦では通算1試合に登板し、1勝0敗、防御率1.00、9奪三振。", summary(pitcher)
    end
  end

  test "tells a batter's average, hits, home runs and RBIs" do
    batter = player(position: "捕手")
    BattingLine.create!(game: game, player: batter, university: @alpha, pa: 5, ab: 4, hits: 2, home_runs: 1, rbi: 3)

    with_stats_everywhere do
      assert_match "リーグ戦では通算1試合に出場し、打率.500、2安打、1本塁打、3打点。", summary(batter)
    end
  end

  test "a member of staff is told by role, with no totals" do
    manager = player(scorebook_id: 1, name: "木村 泰雄", name_kana: nil, enter_year: nil, role: "監督", position: nil, high_school: nil)

    assert_equal "木村 泰雄は、東京六大学野球・#{@alpha.name}の監督。", summary(manager)
  end

  test "says the totals leave out seasons without box scores, or that there are none" do
    missing = [ Season.new(year: 2024, term: "spring"), Season.new(year: 2024, term: "autumn") ]
    batter = player(position: "捕手")
    BattingLine.create!(game: game, player: batter, university: @alpha, pa: 4, ab: 4, hits: 1)

    stub_method(PlayerRanking, :seasons_without_stats, ->(_kind) { missing }) do
      assert_match "成績は試合ごとの記録がある試合の集計で、記録が残っていない2シーズンはふくまない。", summary(batter)
    end

    old = player(scorebook_id: 1, enter_year: 1960)
    all_four_years = PlayerRanking.career_seasons(1960).map { |year, term| Season.new(year: year, term: term) }
    stub_method(PlayerRanking, :seasons_without_stats, ->(_kind) { all_four_years }) do
      assert_match "在籍した時期のリーグ戦は試合ごとの記録が残っておらず、成績はない。", summary(old)
    end
  end
end
