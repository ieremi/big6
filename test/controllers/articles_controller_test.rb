require "test_helper"

class ArticlesControllerTest < ActionDispatch::IntegrationTest
  test "the articles are listed, and each has its own page" do
    get articles_path

    assert_response :success
    assert_select "h1", "読み物"
    assert_select ".news-list a[href=?]", article_path("draft-2026"), text: "2026年ドラフト会議と東京六大学"
  end

  test "the draft article lists who filed and who was picked, with the titles won while they were there" do
    alpha, beta = universities(:one), universities(:two)
    star = Player.create!(scorebook_id: 20231001, university: alpha, name: "一番 星", enter_year: 2023, position: "投手")
    Player.create!(scorebook_id: 20231002, university: alpha, name: "育成 枠", enter_year: 2023, position: "捕手")
    Player.create!(scorebook_id: 20236001, university: beta, name: "二番 手", enter_year: 2023, position: "内野手")

    stub_method(DraftEntrants, :path, ->(_year) { file_fixture("draft_test.yml") }) { get article_path("draft-2026") }

    assert_response :success
    assert_select "h1", "2026年ドラフト会議と東京六大学"
    assert_select "article p", text: /東京六大学からは2人が指名されました（本指名1人、育成1人）。\s*プロ野球志望届を出したのは2大学の3人/
    assert_select "article p", text: /育成選手選択会議では、Alphaの育成 枠（読売ジャイアンツ・育成2位）が指名されました/
    assert_select "article p", text: /1位指名はAlphaの一番 星（阪神タイガース）/
    assert_select "table tbody tr td a[href=?]", player_path(star.scorebook_id), text: "一番 星"
    picked_table = css_select("table").find { |table| table.css("th").map(&:text) == %w[選手 大学 守備 球団 順位 打率 防御率] }
    assert picked_table, "the picks' table has the columns 選手 大学 守備 球団 順位 打率 防御率"
    assert_equal [ "一番 星", "Alpha", "投手", "阪神タイガース", "1位", "---", "---" ], picked_table.css("tbody tr").first.css("td").map { |td| td.text.strip } # no lines yet
    assert_select "table tbody tr td", "読売ジャイアンツ 育成2位"
    assert_select "a[href=?][target=_blank]", "https://npb.jp/draft/2026/"

    # The filers' table sorts in the browser, its dates as 2026-09-05.
    assert_select "table[data-controller=sortable-table] th.sortable button[data-action=?]", "sortable-table#sort", 8
    assert_select "table[data-controller=sortable-table] tbody td", "2026-10-02"
    assert_select "table[data-controller=sortable-table] tbody td[data-sort-value=?]", "", text: "—" # not picked: last whichever way
  end

  test "the strength spread article names the seasons furthest and closest apart, and lists them all" do
    alpha, beta = universities(:one), universities(:two)
    row = ->(year, variance, without) do
      StrengthSpread::Row.new(season: Season.find_or_create_by!(year: year, term: "spring"), variance: variance, variance_without_tokyo: without,
        chances: { alpha => 0.7, beta => 0.3 })
    end
    rows = [ row.(2001, 0.9, 0.2), row.(2002, 0.4, 0.01), row.(2003, 0.6, 0.5) ]

    stub_method(StrengthSpread, :rows, -> { rows }) { get article_path("strength-spread") }

    assert_response :success
    assert_select "article p", text: /もっとも離れていたのは\s*2001年春季\s*、もっとも近かったのは\s*2002年春季\s*でした/
    assert_select "article p", text: /東大を除いた5大学でもっとも近かったのは\s*2002年春季\s*、\s*もっとも離れていたのは\s*2003年春季/
    assert_select "table[data-controller=sortable-table] tbody tr", 3
    assert_select "table tbody td", text: "Alpha70 Beta30", minimum: 1
    assert_select "a[href=?]", strength_seasons_path
  end

  test "the postwar article charts the strengths season by season, with the averages by decade and each one's best and worst" do
    alpha, beta = universities(:one), universities(:two)
    row = ->(year, term, chance) do
      StrengthSpread::Row.new(season: Season.find_or_create_by!(year: year, term: term), variance: 0.5, variance_without_tokyo: 0.1,
        chances: { alpha => chance, beta => 1 - chance })
    end
    rows = [ row.(1938, "autumn", 0.9), row.(2010, "spring", 0.6), row.(2010, "autumn", 0.3), row.(2021, "spring", 0.8) ]

    stub_method(StrengthSpread, :rows, -> { rows }) { get article_path("strength-postwar") }

    assert_response :success
    assert_select "[data-view=chance]:not([hidden]) figure.line-chart svg polyline.line-chart-line", 2
    # One view-switch over the article, so the buttons also switch the figures in the tables.
    assert_select "article[data-controller=view-switch]", 1
    assert_select "[data-controller=view-switch]", 1
    assert_select "article button.period-btn", %w[確率 オッズ 対数オッズ].size
    assert_select "[data-view=odds][hidden] figure[data-line-chart-kind-value=odds]"
    assert_select "[data-view=chance] .line-chart-table tbody tr", 3 # 1938 is before the war
    assert_select "[data-view=chance] svg text.line-chart-axis-label", text: "2010"
    assert_select "table.formula-table tbody th", %w[2010年代 2020年代].size
    assert_select "table tbody tr td", text: /2021年春季（80%/ # alpha's best
    assert_select "table tbody tr td", text: /2010年秋季（30%/ # alpha's worst
    assert_select "table tbody tr td span[data-view=odds][hidden]", text: "4.00" # alpha's best as odds
  end

  test "the home runs article gives the fewest, the most, the mean and the spread, and every season" do
    Game.delete_all
    player = Player.create!(scorebook_id: 1, university: universities(:one), name: "打者", enter_year: 2023, role: "選手")
    { 2001 => 3, 2002 => 5 }.each do |year, count|
      season = Season.create!(year: year, term: "spring")
      game = Game.create!(season:, team0: universities(:one), team1: universities(:two), played_on: Date.new(year, 4, 1), game_number: 1,
        team0_score: 3, team1_score: 1, game_status: "試合終了")
      BattingLine.create!(game:, player:, university: universities(:one), ab: 4, hits: count, home_runs: count)
    end

    get article_path("home-runs-per-season")

    assert_response :success
    assert_select "article p", text: /平均\s*4.0本\s*（標準偏差1.0本）/
    assert_select "article p", text: /2002年春季の5本/
    assert_select "table[data-controller=sortable-table] tbody tr", 2
    assert_select "tr:not(.muted) td", text: "2／2" # the 2000s: both seasons counted
    assert_select "h2", text: /今季/, count: 0

    today = ActiveSupport::TimeZone["Asia/Tokyo"].today
    on = Season.create!(year: today.year + 1, term: "spring")
    [ today - 1, today + 1 ].each_with_index do |day, i|
      game = Game.create!(season: on, team0: universities(:one), team1: universities(:two), played_on: day, game_number: i + 1,
        team0_score: (3 if i.zero?), team1_score: (1 if i.zero?), game_status: i.zero? ? "試合終了" : "試合前")
      BattingLine.create!(game:, player:, university: universities(:one), ab: 4, hits: 2, home_runs: 2) if i.zero?
    end

    get article_path("home-runs-per-season")

    assert_select "h2", text: "今季（#{on.title}、途中）"
    assert_select "article p", text: /ここまで1試合で\s*2本\s*、1試合あたり\s*2.00本.*全2試合を終えると、約4本/m
  end

  test "the fifty years article's old URL is sent on to the postwar one" do
    get article_path("strength-50-years")

    assert_redirected_to article_path("strength-postwar")
    assert_response :moved_permanently
  end

  test "the freshman batting champions article lists them, how many won it in each year, and the 1年生 leading now" do
    Player.create!(scorebook_id: 2, university: universities(:two), name: "一年秋", enter_year: 2024, role: "選手", high_school: "花巻東")
    game = Game.where(season: seasons(:one)).order(:played_on).first
    rookie = Player.create!(scorebook_id: 4, university: game.team0, name: "新人", enter_year: 2026, role: "選手")
    BattingLine.create!(game:, player: rookie, university: game.team0, pa: 4, ab: 4, hits: 3)

    stub_method(LeadingHitters, :path, -> { file_fixture("leading_hitters_test.yml") }) { get article_path("freshman-leading-hitters") }

    assert_response :success
    assert_select "table[data-controller=sortable-table] tbody tr", 1
    assert_select "table tbody td a[href=?]", player_path(2), text: "一年秋"
    assert_select "table tbody td", text: "花巻東"
    assert_select "table.formula-table tbody tr", 5 # 1年生 to 4年生, and わからない
    assert_select "article p", text: /上位10位までにいる1年生は\s*新人（.+、1位、\.750）です。\s*このまま終われば/
    assert_select "article p.muted", text: /名鑑にない選手（名鑑外）/
  end

  test "the 越後 article says what each batter with games left needs to pass him" do
    Game.delete_all
    alpha, beta = universities(:one), universities(:two)
    season = Season.find_or_create_by!(year: 2026, term: "autumn")
    played = Game.create!(season:, team0: alpha, team1: beta, played_on: Date.new(2026, 10, 31), game_number: 1, team0_score: 3, team1_score: 1, game_status: "試合終了")
    Game.create!(season:, team0: beta, team1: alpha, played_on: Date.current + 3, game_number: 2, game_status: "試合前")
    echigo = Player.create!(scorebook_id: 20266006, university: alpha, name: "越後 駿祐", enter_year: 2026, role: "選手")
    rival = Player.create!(scorebook_id: 2, university: beta, name: "打者", enter_year: 2025, role: "選手")
    BattingLine.create!(game: played, player: echigo, university: alpha, pa: 4, ab: 4, hits: 2)
    BattingLine.create!(game: played, player: rival, university: beta, pa: 4, ab: 4, hits: 1)

    get article_path("echigo-batting-title")

    assert_response :success
    assert_select "article p", text: /越後 駿祐選手（.+、1年）は\s*1位、打率\.500/
    assert_select "article table tbody tr", 1
    assert_select "article table tbody td a[href=?]", player_path(rival), text: "打者"
  end

  test "the 2026 autumn highlights give three or four points for each university done, linking the players" do
    get article_path("autumn-2026-highlights")

    assert_response :success
    assert_select "article h2.card-heading", 4
    assert_select "article ul", 4
    assert_select "article li a[href=?]", player_path(20266006), text: "越後駿祐"
  end

  test "an article that isn't there is not found" do
    get article_path("no-such-article")

    assert_response :not_found
  end
end
