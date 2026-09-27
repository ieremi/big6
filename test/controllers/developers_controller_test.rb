require "test_helper"

class DevelopersControllerTest < ActionDispatch::IntegrationTest
  test "the index and each page of docs/ are shown, with a link back and to the source" do
    get developers_path
    assert_response :success
    assert_select "title", "東京六大学野球のデータを扱う開発者向けの解説 - Big6"
    assert_select ".markdown-body a[href=?]", developer_page_path("league-site-game-page")

    get developer_page_path("league-site-game-page")
    assert_response :success
    assert_select "title", "連盟公式サイト（big6.gr.jp）の試合ページのURL - 開発者向けの解説 - Big6"
    assert_select "a[href=?]", developers_path, text: "← 開発者向けの解説"
    assert_select ".markdown-body table", minimum: 3
    assert_select "a[href=?]", "https://github.com/ieremi/big6/blob/main/docs/league-site-game-page.md"
  end

  test "a page that isn't there is not found" do
    get "/developers/no-such-page"
    assert_response :not_found
  end

  test "the API docs and the sitemap lead to the notes" do
    get api_docs_path
    assert_select "a[href=?]", developers_path

    get sitemap_path
    assert_includes response.body, "/developers/league-site-game-page"
  end
end
