require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "the sidebar and the home page link to the players list and the rankings, ending with Web API" do
    get root_url

    assert_response :success
    [ "nav.nav-drawer a", "nav.home-links a" ].each do |selector|
      labels = css_select(selector).map { |link| link.text.squish }

      assert_equal [ "ランキング 7", "Web API 8" ], labels.last(2), "last links of #{selector}"
    end
    assert_select "nav.home-links a[href=?]", players_path
    assert_select "nav.home-links a[href=?]", rankings_path
    assert_select "nav.nav-drawer a[href=?][data-shortcut='6']", players_path
    assert_select "nav.nav-drawer a[href=?][data-shortcut='7']", rankings_path
    assert_select "nav.nav-drawer a[href=?][data-shortcut='8']", api_docs_path
  end

  test "the sidebar's shortcut keys are numbered in the order the links appear" do
    get root_url

    keys = css_select("nav.nav-drawer a").map { |link| link["data-shortcut"] }

    assert_equal keys.sort, keys
    assert_equal keys.uniq, keys
  end
end
