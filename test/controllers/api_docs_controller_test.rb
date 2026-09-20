require "test_helper"

class ApiDocsControllerTest < ActionDispatch::IntegrationTest
  OG_ENDPOINTS = {
    "/api/v1/universities/:slug/og.png" => "/api/v1/universities/rikkio/og.png",
    "/api/v1/seasons/:year/:term/og.png" => "/api/v1/seasons/1997/autumn/og.png",
    "/api/v1/games/:year/:term/:team0/:team1/:round/og.png" => "/api/v1/games/1997/autumn/rikkio/tokyo/1/og.png",
    "/api/v1/matchups/:team0_slug/:team1_slug/og.png" => "/api/v1/matchups/rikkio/tokyo/og.png?period=10",
    "/api/v1/players/:id/og.png" => "/api/v1/players/20236010/og.png"
  }.freeze

  test "documents every players endpoint" do
    get api_docs_url

    assert_response :success
    [ "/api/v1/players", "/api/v1/players/:id", "/api/v1/players/:id/games", "/api/v1/players/:id/og.png" ].each do |path|
      assert_select "h3 code", text: path
    end
  end

  test "documents the players search parameters" do
    get api_docs_url

    %w[q university start_year role status page].each do |parameter|
      assert_select "table td code", text: parameter
    end
  end

  test "has a working try-it box for the players endpoints" do
    get api_docs_url

    assert_select ".api-sandbox input[value=?]", "/players/20236010"
    assert_select ".api-sandbox input[value=?]", "/players/20236010/games"
  end

  test "documents each OG image endpoint with a try-it box" do
    get api_docs_url

    OG_ENDPOINTS.each do |heading, image_url|
      assert_select "h3 code", text: heading
      assert_select ".api-sandbox.api-image input[value=?]", image_url.delete_prefix("/api/v1") # the editable request path
      assert_select ".api-sandbox.api-image button", text: "試す", minimum: 1
      assert_select ".api-sandbox.api-image a[href=?]", image_url
    end
  end

  test "an image box starts with the image hidden and not yet requested" do
    get api_docs_url

    assert_select ".api-sandbox.api-image a[hidden][data-api-sandbox-target=previewLink]", OG_ENDPOINTS.size
    assert_select ".api-sandbox.api-image img[data-api-sandbox-target=preview]", OG_ENDPOINTS.size
    assert_select ".api-sandbox.api-image img[src]", 0 # no src, so the browser fetches nothing until 試す
  end

  test "an image box shows no response text, only a hidden message line" do
    get api_docs_url

    assert_select ".api-sandbox.api-image details", 0
    assert_select ".api-sandbox.api-image pre", 0
    assert_select ".api-sandbox.api-image [data-api-sandbox-target=output]", 0
    assert_select ".api-sandbox.api-image p[data-api-sandbox-target=message][hidden]", OG_ENDPOINTS.size
  end

  test "each image box is wired to the sandbox controller and run by its button and the Enter key" do
    get api_docs_url

    assert_select ".api-sandbox.api-image[data-controller=api-sandbox]", OG_ENDPOINTS.size
    assert_select ".api-sandbox.api-image button[data-action=?]", "api-sandbox#run", OG_ENDPOINTS.size
    assert_select ".api-sandbox.api-image input[data-action*=?]", "api-sandbox#run", OG_ENDPOINTS.size
  end

  test "the JSON boxes still show the response text" do
    get api_docs_url

    assert_select ".api-sandbox:not(.api-image) details pre[data-api-sandbox-target=output]", minimum: 10
  end

  test "documents the query parameters of the season and matchup images" do
    get api_docs_url

    assert_select "table td code", text: "label"
    assert_select "table td code", text: "period"
  end

  test "mentions that the JSON carries og_image_url" do
    get api_docs_url

    assert_select "p.muted code", text: "og_image_url"
  end

  test "documents obp, slg, and ops, and that sacrifice flies are left out of on-base" do
    get api_docs_url

    %w[obp slg ops total_bases].each { |field| assert_select "p code", text: field }
    assert_match "犠飛は含めていません", response.body
  end
end
