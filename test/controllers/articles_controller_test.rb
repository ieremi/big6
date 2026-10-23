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

  test "an article that isn't there is not found" do
    get article_path("no-such-article")

    assert_response :not_found
  end
end
