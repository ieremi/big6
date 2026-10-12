require "test_helper"

class SeasonSummaryTest < ActiveSupport::TestCase
  setup do
    @alpha = universities(:one)
    @beta = universities(:two)
    Game.delete_all
  end

  def season(year, term)
    Season.find_or_create_by!(year: year, term: term)
  end

  def game(season, day, number, team0_score, team1_score, **attributes)
    Game.create!({ season: season, team0: @alpha, team1: @beta, played_on: day, game_number: number,
      team0_score: team0_score, team1_score: team1_score, game_status: "試合終了" }.merge(attributes))
  end

  def summary(season, finished: true)
    games = season.games.includes(:team0, :team1).order(:played_on).to_a
    stub_method(season, :finished?, -> { finished }) { SeasonSummary.new(season, Standings.new(season, games: games), games).to_s }
  end

  test "a finished season tells its champion with 勝ち点 and record" do
    s = season(2025, "autumn")
    game(s, "2025-09-13", 1, 3, 1)
    game(s, "2025-09-14", 2, 2, 0)

    assert_equal "東京六大学野球 2025年秋季リーグ戦は、#{@alpha.short_name}が勝ち点1（2勝0敗）で優勝した。", summary(s)
  end

  test "a season decided by a playoff tells its winner" do
    s = season(2025, "spring")
    game(s, "2025-05-17", 1, 3, 1)
    game(s, "2025-05-18", 2, 0, 2)
    game(s, "2025-05-19", 3, 2, 1)
    game(s, "2025-06-04", 1, 5, 6, counted_in_stats: false)

    assert_match "優勝決定戦で#{@beta.short_name}が6-5で勝って優勝した。", summary(s)
  end

  test "a season under way tells who leads after how many games" do
    s = season(2026, "autumn")
    game(s, "2026-09-12", 1, 3, 1)

    assert_equal "東京六大学野球 2026年秋季リーグ戦は、9月12日までに1試合を終え、#{@alpha.short_name}が勝ち点0（1勝0敗）で首位。", summary(s, finished: false)
  end

  test "claims no champion for 2020 and 2021, played in other formats" do
    s = season(2021, "autumn")
    game(s, "2021-09-18", 1, 3, 1)

    assert_equal "東京六大学野球 2021年秋季リーグ戦は、全1試合が行われた。", summary(s)
  end

  test "a past season without games has no record" do
    assert_equal "東京六大学野球 1944年春季リーグ戦は、試合の記録がない。", summary(season(1944, "spring"))
  end
end
