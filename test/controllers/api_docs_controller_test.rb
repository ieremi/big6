require "test_helper"

class ApiDocsControllerTest < ActionDispatch::IntegrationTest
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
    assert_select ".api-sandbox input[value=?]", "/players/20236010/og.png"
  end
end
