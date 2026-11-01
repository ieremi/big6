require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "the sidebar and the home page link to the players list, the rankings and the articles, ending with Web API" do
    get root_url

    assert_response :success
    [ "nav.nav-drawer a", "nav.home-links a" ].each do |selector|
      labels = css_select(selector).map { |link| link.text.squish }

      assert_equal [ "ランキング 7", "読み物 8", "Web API 9" ], labels.last(3), "last links of #{selector}"
    end
    assert_select "nav.home-links a[href=?]", players_path
    assert_select "nav.home-links a[href=?]", rankings_path
    assert_select "nav.nav-drawer a[href=?][data-shortcut='6']", players_path
    assert_select "nav.nav-drawer a[href=?][data-shortcut='7']", rankings_path
    assert_select "nav.nav-drawer a[href=?][data-shortcut='8']", articles_path
    assert_select "nav.nav-drawer a[href=?][data-shortcut='9']", api_docs_path
  end

  test "the home page lists today's games with their starting pitchers, linked to the game" do
    Game.delete_all
    today = ActiveSupport::TimeZone["Asia/Tokyo"].today
    game = Game.create!(season: seasons(:two), team0: universities(:one), team1: universities(:two), played_on: today, game_number: 2, game_order: 1,
      game_status: "試合前", league_official_data: { "lineup" => [ { "side" => "top", "order" => nil, "position" => "投", "name" => "新人" } ] })

    get root_url

    assert_select "section.next-game-day h2", text: /\A今日の試合/
    assert_select "section.next-game-day a[href=?]", matchup_game_path("alpha", "beta", game.season.year, game.season.term, 2)
    assert_select "section.next-game-day li", text: /先発 新人※/
  end

  test "the home page has no games section with no game in the week ahead" do
    Game.delete_all

    get root_url

    assert_select "section.next-game-day", 0
  end

  test "the sidebar's shortcut keys are numbered in the order the links appear" do
    get root_url

    keys = css_select("nav.nav-drawer a").map { |link| link["data-shortcut"] }

    assert_equal keys.sort, keys
    assert_equal keys.uniq, keys
  end
end
