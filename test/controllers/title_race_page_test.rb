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
    assert_select ".title-race-table thead th.title-race-edge", 2 # the last cell on the left of each header row
  end

  test "once the champion is settled, the page says so instead of a grid" do
    Game.where(played_on: [ Date.new(2026, 5, 9), Date.new(2026, 5, 10) ]).each do |game|
      game.update!(game_status: "試合終了", team0_score: game.team0 == @alpha ? 3 : 0, team1_score: game.team0 == @alpha ? 0 : 3)
    end

    get standings_season_url(2026, "spring")

    assert_select "section.title-race", text: /Alphaの優勝が決まりました/
    assert_select ".title-race-table", 0
  end

  test "a season over names its champion" do
    Game.where(played_on: Date.new(2026, 5, 9)..).delete_all

    get standings_season_url(2026, "spring")

    assert_select "section.title-race strong", "Alphaが優勝しました。"
    assert_select "nav.title-race-games a.period-btn", 2 # after each of the two games
  end

  test "a chart shows each university's chance game by game, with its figures in a table" do
    Game.where(played_on: [ Date.new(2026, 5, 9), Date.new(2026, 5, 10) ]).each do |game|
      game.update!(game_status: "試合終了", team0_score: game.team0 == @alpha ? 3 : 0, team1_score: game.team0 == @alpha ? 0 : 3)
    end

    get standings_season_url(2026, "spring")

    assert_select "section.title-race figure.line-chart[data-controller=line-chart]" do
      assert_select "svg[role=img][tabindex='0'] polyline.line-chart-line", 3 # each university with a chance at some point
      assert_select "svg polyline.line-chart-line[style=?]", "stroke: #{@alpha.color}" # as in the grid
      assert_select "svg text.line-chart-end-label", "Alpha 100%"
      assert_select "svg text.line-chart-axis-label", text: "第1週"
      assert_select ".line-chart-legend li", 3
      assert_select ".line-chart-table tbody tr", 4 # after each of the four games
      assert_select ".line-chart-table tbody tr:last-child td", text: "5月10日のGamma 0-3 Alpha（2回戦）"
    end
  end

  test "a chart shows each university's strength from the opening day on, game by game" do
    get standings_season_url(2026, "spring")

    assert_select "section.team-strength h2", "強さの推移"
    assert_select "section.team-strength [data-view=chance]:not([hidden]) figure.line-chart[data-controller=line-chart]" do
      assert_select "svg polyline.line-chart-line", 3 # every university of the season
      assert_select ".line-chart-table tbody tr", 3 # the opening day and the two games ended
      assert_select ".line-chart-table tbody tr:first-child td", text: "開幕前"
    end
  end

  test "buttons show the strengths as a chance, odds or log odds, the same figures each way" do
    get standings_season_url(2026, "spring")

    assert_select "section.team-strength [data-controller=view-switch] button.period-btn", %w[確率 オッズ 対数オッズ].size
    assert_select "section.team-strength button.active[aria-pressed=true][data-view=chance]", "確率"
    assert_select "section.team-strength div[data-view=odds][hidden] figure[data-line-chart-kind-value=odds]"
    assert_select "section.team-strength div[data-view=logit][hidden] figure[data-line-chart-kind-value=logit]"

    # The same university's last value, each way: a chance p, its odds p / (1 - p), and their log.
    chances = css_select("[data-view=chance] .line-chart-table tbody tr:last-child td.num").map { |td| td.text.delete("%").to_f / 100 }
    odds = css_select("[data-view=odds] .line-chart-table tbody tr:last-child td.num").map { |td| td.text.to_f }
    logits = css_select("[data-view=logit] .line-chart-table tbody tr:last-child td.num").map { |td| td.text.to_f }
    chances.zip(odds, logits).each do |chance, odd, logit|
      assert_in_delta chance / (1 - chance), odd, 0.02
      assert_in_delta Math.log(odd), logit, 0.02
    end
  end

  test "the strength chart links to the page explaining it, whose figures come from the model" do
    get standings_season_url(2026, "spring")
    assert_select "section.team-strength a[href=?]", strength_seasons_path

    get strength_seasons_url

    assert_response :success
    assert_select "h1", "強さとは"
    assert_select ".formula", text: /#{TeamStrength::PAST_WEIGHT} ×（直近10シーズンの勝率）＋ #{TeamStrength::CURRENT_WEIGHT} ×（今季の勝率）/
    assert_select ".formula-table td", "50.0%" # level sides
    assert_select "p", text: /対数損失 #{TeamStrength::CHECK[:log_loss_without_tokyo]}/
  end

  test "a button picks the game, and the race is the one once it had ended" do
    Game.where(played_on: [ Date.new(2026, 5, 9), Date.new(2026, 5, 10) ]).each do |game|
      game.update!(game_status: "試合終了", team0_score: game.team0 == @alpha ? 3 : 0, team1_score: game.team0 == @alpha ? 0 : 3)
    end

    get standings_season_url(2026, "spring")
    assert_select "turbo-frame#title-race[data-turbo-action=advance] nav.title-race-games .period-toolbar", 2 # weeks 1 and 2
    assert_select "nav.title-race-games .period-toolbar:first-child .title-race-week", "第1週"
    assert_select "nav.title-race-games a.period-btn", 4
    assert_select "nav.title-race-games a[href=?]", standings_season_path(2026, "spring", after: "2026-05-03-beta-alpha"), text: "5/3 Beta-Alpha"
    assert_select "nav.title-race-games a.active[aria-current=true]", "5/10 Gamma-Alpha"
    assert_select "turbo-frame#title-race p.title-race-as-of", "5月10日のGamma 0-3 Alpha（2回戦）のあとの優勝のゆくえです。"
    assert_select "turbo-frame#title-race", text: /Alphaの優勝が決まりました/

    get standings_season_url(2026, "spring", after: "2026-05-03-beta-alpha")
    assert_select "nav.title-race-games a.active", "5/3 Beta-Alpha"
    assert_select "turbo-frame#title-race p.title-race-as-of", "5月3日のBeta 0-2 Alpha（2回戦）のあとの優勝のゆくえです。"
    assert_select "turbo-frame#title-race .title-race-table td.title-race-cell", 16
  end
end
