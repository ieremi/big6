require "test_helper"

class SeoHelperTest < ActionView::TestCase
  setup do
    @alpha = universities(:one)
    @beta = universities(:two)
    Game.delete_all
  end

  def game(day, team0_score, team1_score, season: seasons(:one), number: 1)
    Game.create!(season: season, team0: @alpha, team1: @beta, played_on: day, game_number: number,
      team0_score: team0_score, team1_score: team1_score, game_status: "試合終了")
  end

  test "a title names the page, then the league and the site" do
    assert_equal "2026年秋季 順位表 - 東京六大学野球 - Big6", site_title("2026年秋季 順位表")
    assert_equal "立大 vs 東大 対戦成績 - 東京六大学野球 - Big6", site_title(nil, "立大 vs 東大 対戦成績")
  end

  test "a standings description gives every university's place, 勝ち点 and record" do
    game("2026-04-11", 3, 1)
    game("2026-04-12", 2, 0, number: 2)

    description = standings_meta_description(seasons(:one), Standings.new(seasons(:one)))

    assert_match "東京六大学野球 2026年春季の順位表。1位 #{@alpha.short_name}（勝ち点1、2勝0敗）、2位 #{@beta.short_name}（勝ち点0、0勝2敗）", description
  end

  test "a season description tells who leads, or that nothing is decided yet" do
    assert_match "まだ試合結果はありません", season_meta_description(seasons(:two), Standings.new(seasons(:two)))

    game("2026-04-11", 3, 1)
    assert_match "#{@alpha.short_name}（勝ち点0、1勝0敗）", season_meta_description(seasons(:one), Standings.new(seasons(:one)))
  end

  test "a matchup description counts the wins and draws of the games it lists" do
    games = [ game("2026-04-11", 3, 1), game("2026-04-12", 0, 2, number: 2), game("2026-04-13", 1, 1, number: 3) ]

    assert_equal "東京六大学野球 #{@alpha.short_name}と#{@beta.short_name}の2026年春季の対戦成績（#{@alpha.short_name}1勝、#{@beta.short_name}1勝、1分）と試合結果。",
      matchup_meta_description(@alpha, @beta, games, period_label: "2026年春季")
  end

  test "a player description gives the profile and the career totals" do
    player = Player.create!(scorebook_id: 1, university: @alpha, name: "田中 優飛", enter_year: 2024, role: "選手", position: "投手", high_school: "仙台育英")
    PitchingLine.create!(game: game("2026-04-11", 3, 1), player: player, university: @alpha, outs: 27, earned_runs: 1, strikeouts: 9, wins: 1)

    description = player_meta_description(player, PlayerStats.new(player))

    assert_equal "#{@alpha.name} 2024年入学 選手 投手（仙台育英）。東京六大学野球リーグ戦の通算成績：投手 1試合 1勝0敗 防御率1.00 9奪三振。", description
  end
end
