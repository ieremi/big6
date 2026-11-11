require "test_helper"

# The JSON-LD (schema.org) in the head of the public pages (SeoHelper).
class StructuredDataTest < ActionDispatch::IntegrationTest
  # The page's own JSON-LD; the BreadcrumbList that goes with its breadcrumbs apart (breadcrumb_list).
  def structured_data
    all_structured_data.reject { |data| data["@type"] == "BreadcrumbList" }
  end

  def breadcrumb_list
    all_structured_data.find { |data| data["@type"] == "BreadcrumbList" }
  end

  def all_structured_data
    css_select('script[type="application/ld+json"]').map { |node| JSON.parse(node.text) }
  end

  test "a game page's breadcrumbs go through its season and the pair's games that season, and say so to machines too" do
    get matchup_game_url("alpha", "beta", 2026, "spring", 1)

    labels = [ "トップ", "シーズン一覧", "2026年春季", "#{universities(:one).short_name} vs #{universities(:two).short_name}", "1回戦" ]
    assert_equal labels, css_select("nav.breadcrumbs li").map { |li| li.text.strip }
    assert_select "nav.breadcrumbs li[aria-current=page]", text: "1回戦"
    assert_select "nav.breadcrumbs a[href=?]", season_path(2026, "spring")
    items = breadcrumb_list["itemListElement"]
    assert_equal labels, items.map { |item| item["name"] }
    assert_equal [ root_url.chomp("/"), season_url(2026, "spring") ], items.values_at(0, 2).map { |item| item["item"].chomp("/") }
    assert_equal matchup_game_url("alpha", "beta", 2026, "spring", 1), items.last["item"]
  end

  test "the top page has no breadcrumbs, and a season tab's end with the tab" do
    get root_url
    assert_select "nav.breadcrumbs", 0
    assert_nil breadcrumb_list

    get standings_season_url(2026, "spring")
    assert_equal [ "トップ", "シーズン一覧", "2026年春季", "順位・優勝のゆくえ" ], css_select("nav.breadcrumbs li").map { |li| li.text.strip }
  end

  test "the home page describes the site" do
    get root_url

    assert_equal [ [ "WebSite", "Big6", root_url ] ], structured_data.map { |data| data.values_at("@type", "name", "url") }
  end

  test "a game page describes the game as a sports event between the two universities" do
    get matchup_game_url("alpha", "beta", 2026, "spring", 1)

    event = structured_data.sole
    assert_equal [ "https://schema.org", "SportsEvent", "2026-08-10", "https://schema.org/EventScheduled" ],
      event.values_at("@context", "@type", "startDate", "eventStatus")
    assert_equal [ universities(:one).name, universities(:two).name ], [ event.dig("awayTeam", "name"), event.dig("homeTeam", "name") ]
    assert_equal "東京六大学野球連盟", event.dig("organizer", "name")
    assert_match "東京六大学野球", event["description"]
  end

  test "a player page describes the player and their university, with a staff member's role only" do
    player = Player.create!(scorebook_id: 20246018, university: universities(:one), name: "田中 優飛", name_kana: "タナカ ユウト",
      enter_year: 2024, role: "選手", high_school: "仙台育英")
    manager = Player.create!(scorebook_id: 19951099, university: universities(:one), name: "木村 泰雄", role: "監督")

    get player_url(player)
    person = structured_data.sole
    assert_equal [ "Person", "田中 優飛", "タナカ ユウト", universities(:one).name, "仙台育英" ],
      [ person["@type"], person["name"], person["alternateName"], person.dig("memberOf", "name"), person.dig("alumniOf", "name") ]
    assert_nil person["jobTitle"]

    get player_url(manager)
    assert_equal "監督", structured_data.sole["jobTitle"]
  end

  test "a university page describes the team as a member of the league" do
    get university_url("alpha")

    team = structured_data.sole
    assert_equal [ "SportsTeam", universities(:one).name, "Baseball", "東京六大学野球連盟" ], [ team["@type"], team["name"], team["sport"], team.dig("memberOf", "name") ]
  end

  test "a name with a closing script tag in it can't end the block" do
    player = Player.create!(scorebook_id: 1, university: universities(:one), name: "</script><script>alert(1)</script>", role: "選手")

    get player_url(player)

    assert_equal "</script><script>alert(1)</script>", structured_data.sole["name"]
    assert_no_match "</script><script>alert(1)", response.body
  end
end
