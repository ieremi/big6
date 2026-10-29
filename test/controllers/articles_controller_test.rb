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

  test "the fifty years article's old URL is sent on to the postwar one" do
    get article_path("strength-50-years")

    assert_redirected_to article_path("strength-postwar")
    assert_response :moved_permanently
  end

  test "an article that isn't there is not found" do
    get article_path("no-such-article")

    assert_response :not_found
  end
end
