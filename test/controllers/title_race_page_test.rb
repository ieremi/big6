require "test_helper"

# 優勝のゆくえ (TitleRace) under the standings table.
class TitleRacePageTest < ActionDispatch::IntegrationTest
  setup do
    Game.delete_all
    @alpha = universities(:one)
    @beta = universities(:two)
    @gamma = University.create!(name: "Gamma University", short_name: "Gamma", slug: "gamma", position: 3)
    [ [ @alpha, @beta, 2, 1, [ 3, 1 ] ], [ @beta, @alpha, 3, 2, [ 0, 2 ] ],
      [ @alpha, @gamma, 9, 1, nil ], [ @gamma, @alpha, 10, 2, nil ], [ @beta, @gamma, 16, 1, nil ], [ @gamma, @beta, 17, 2, nil ] ].each do |team0, team1, day, number, score|
      Game.create!(season: seasons(:one), team0: team0, team1: team1, played_on: Date.new(2026, 5, day), game_number: number,
        team0_score: score&.first, team1_score: score&.last, game_status: score ? "試合終了" : "試合前")
    end
  end

  test "the standings page shows the champion for every way the open cards can end" do
    get standings_season_url(2026, "spring")

    assert_select "section.title-race h2", "優勝のゆくえ"
    assert_select ".title-race-table thead th.title-race-card", text: "③Beta-Gamma"
    assert_select ".title-race-table tbody th", text: "②Alpha-Gamma", count: 0
    assert_select ".title-race-table thead th.title-race-card", text: "②Alpha-Gamma"
    assert_select ".title-race-table tbody tr", 4 # alpha v gamma: 2-0, 2-1, 1-2, 0-2
    assert_select ".title-race-table td.title-race-cell", 16
    assert_select ".title-race-table td.title-race-playoff[title=?]", "Alpha・Beta・Gammaの優勝決定戦", text: "AlphaBetaGamma"
    assert_select "section.title-race p.muted", text: /優勝の可能性（残りの試合をすべて五分五分とした場合）：Alpha 64.6%、Gamma 33.3%、Beta 2.1%/
  end

  test "a card along the top is named above its results, and the cards down the left over their column" do
    get standings_season_url(2026, "spring")

    header_rows = css_select(".title-race-table thead tr")
    assert_equal 2, header_rows.size
    assert_equal [ "", "③Beta-Gamma" ], header_rows[0].css("th").map { |th| th.text.strip }
    assert_equal "4", header_rows[0].css("th").last["colspan"]
    assert_equal [ "②Alpha-Gamma", "2-0", "2-1", "1-2", "0-2" ], header_rows[1].css("th").map { |th| th.text.strip }
  end

  test "once the champion is settled, the page says so instead of a grid" do
    Game.where(played_on: [ Date.new(2026, 5, 9), Date.new(2026, 5, 10) ]).each do |game|
      game.update!(game_status: "試合終了", team0_score: game.team0 == @alpha ? 3 : 0, team1_score: game.team0 == @alpha ? 0 : 3)
    end

    get standings_season_url(2026, "spring")

    assert_select "section.title-race", text: /Alphaの優勝が決まりました/
    assert_select ".title-race-table", 0
  end

  test "a season over has no title race" do
    Game.where(played_on: Date.new(2026, 5, 9)..).delete_all

    get standings_season_url(2026, "spring")

    assert_select "section.title-race", 0
  end
end
