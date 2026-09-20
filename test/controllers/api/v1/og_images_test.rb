require "test_helper"

# The Web API's OG images are the same PNGs the site's pages use for og:image.
class Api::V1::OgImagesTest < ActionDispatch::IntegrationTest
  setup do
    @alpha = universities(:one)
    @beta = universities(:two)
  end

  def png_from(url)
    get url

    assert_response :success
    assert_equal "image/png", response.media_type
    assert_equal "\x89PNG".b, response.body.b[0, 4]
    response.body.b
  end

  def assert_same_image_as_the_site(api_url, site_url)
    assert_equal png_from(site_url), png_from(api_url), "#{api_url} should match #{site_url}"
  end

  def json
    JSON.parse(response.body)
  end

  # ---- the images

  test "a university's image is the university page's" do
    assert_same_image_as_the_site api_v1_university_og_image_url(@alpha.slug), university_og_image_url(@alpha.slug)
  end

  test "a season's image is the season page's, with an optional label" do
    assert_same_image_as_the_site api_v1_season_og_image_url(2026, "spring"), season_og_image_url(2026, "spring")
    assert_same_image_as_the_site api_v1_season_og_image_url(2026, "spring", label: "Champion"), season_og_image_url(2026, "spring", label: "Champion")
    assert_not_equal png_from(api_v1_season_og_image_url(2026, "spring")), png_from(api_v1_season_og_image_url(2026, "spring", label: "Champion"))
  end

  test "a game's image is the game page's, whichever way round the teams are given" do
    site = game_og_image_url(@alpha.slug, @beta.slug, 2026, "spring", 1)

    assert_same_image_as_the_site api_v1_game_og_image_url(2026, "spring", @alpha.slug, @beta.slug, 1), site
    assert_same_image_as_the_site api_v1_game_og_image_url(2026, "spring", @beta.slug, @alpha.slug, 1), site
  end

  test "a matchup's image is the matchup pages': all-time, by period, by year, by season" do
    assert_same_image_as_the_site api_v1_matchup_og_image_url(@alpha.slug, @beta.slug), matchup_og_image_url(@alpha.slug, @beta.slug)
    assert_same_image_as_the_site api_v1_matchup_og_image_url(@alpha.slug, @beta.slug, period: "10"), matchup_og_image_url(@alpha.slug, @beta.slug, period: "10")
    assert_same_image_as_the_site api_v1_matchup_og_image_url(@alpha.slug, @beta.slug, year: 2026), matchup_year_og_image_url(@alpha.slug, @beta.slug, 2026)
    assert_same_image_as_the_site api_v1_matchup_og_image_url(@alpha.slug, @beta.slug, year: 2026, term: "spring"),
      matchup_season_og_image_url(@alpha.slug, @beta.slug, 2026, "spring")
  end

  # ---- errors

  test "an image for something that does not exist is a JSON 404" do
    [
      api_v1_university_og_image_url("nowhere"),
      api_v1_season_og_image_url(1900, "spring"),
      api_v1_game_og_image_url(2026, "spring", @alpha.slug, @beta.slug, 99),
      api_v1_game_og_image_url(2026, "spring", @alpha.slug, "nowhere", 1),
      api_v1_matchup_og_image_url(@alpha.slug, "nowhere"),
      api_v1_matchup_og_image_url(@alpha.slug, @beta.slug, year: 2026, term: "nonesuch")
    ].each do |url|
      get url

      assert_response :not_found, url
      assert_equal({ "error" => "not found" }, json, url)
    end
  end

  # ---- og_image_url in the JSON

  test "each show payload carries the URL of its image" do
    get api_v1_university_url(@alpha.slug)
    assert_equal api_v1_university_og_image_url(@alpha.slug), json["og_image_url"]

    get "/api/v1/seasons/2026/spring"
    assert_equal api_v1_season_og_image_url(2026, "spring"), json["og_image_url"]

    get "/api/v1/games/2026/spring/#{@alpha.slug}/#{@beta.slug}/1"
    assert_equal api_v1_game_og_image_url(2026, "spring", @alpha.slug, @beta.slug, 1), json["og_image_url"]

    get "/api/v1/matchups/#{@alpha.slug}/#{@beta.slug}"
    assert_equal api_v1_matchup_og_image_url(@alpha.slug, @beta.slug), json["og_image_url"]
  end

  test "a matchup payload's image URL keeps the season it was asked for" do
    get "/api/v1/matchups/#{@alpha.slug}/#{@beta.slug}", params: { year: 2026, term: "spring" }

    assert_equal api_v1_matchup_og_image_url(@alpha.slug, @beta.slug, year: "2026", term: "spring"), json["og_image_url"]
  end

  test "every advertised image URL actually serves an image" do
    get "/api/v1/games/2026/spring/#{@alpha.slug}/#{@beta.slug}/1"
    game_url = json["og_image_url"]
    get "/api/v1/players/#{Player.create!(scorebook_id: 20236010, university: @alpha, name: '落合 智哉', enter_year: 2023).scorebook_id}"
    player_url = json["og_image_url"]

    [ game_url, player_url ].each { |url| png_from(url) }
  end
end
