require "test_helper"

class SitemapsControllerTest < ActionDispatch::IntegrationTest
  def locs
    response.body.scan(%r{<loc>([^<]*)</loc>}).flatten
  end

  test "the sitemap is an index of the pages, games and players sitemaps" do
    get sitemap_url(format: :xml)

    assert_response :success
    assert_includes response.body, "<sitemapindex"
    assert_equal %w[pages games players].map { |part| sitemap_part_url(part, format: :xml) }, locs
    assert_equal "http://www.example.com/sitemaps/players.xml", locs.last
  end

  test "the players sitemap has every player's page, newest entrants first" do
    old = Player.create!(scorebook_id: 19951001, university: universities(:one), name: "山田 太郎", enter_year: 1995)
    young = Player.create!(scorebook_id: 20246018, university: universities(:one), name: "田中 優飛", enter_year: 2024)

    get sitemap_part_url("players", format: :xml)

    assert_response :success
    assert_equal [ player_url(young), player_url(old) ], locs
    assert_includes response.body, "<lastmod>"
  end

  test "the pages sitemap has the seasons and universities, the games sitemap the games" do
    get sitemap_part_url("pages", format: :xml)
    assert_includes locs, season_url(2026, "spring")
    assert_includes locs, university_url("alpha")
    assert locs.none? { |loc| loc.include?("/players/") && loc != players_url }

    get sitemap_part_url("games", format: :xml)
    assert_includes locs, matchup_game_url("alpha", "beta", 2026, "spring", 1)
  end

  test "there is no other sitemap" do
    get "/sitemaps/everything.xml"

    assert_response :not_found
  end
end
