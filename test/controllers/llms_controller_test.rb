require "test_helper"

class LlmsControllerTest < ActionDispatch::IntegrationTest
  test "describes the site for AI assistants in plain text, starting with its name" do
    get "/llms.txt"

    assert_response :success
    assert_equal "text/plain", response.media_type
    assert response.body.start_with?("# Big6（東京六大学野球データベース）\n\n> ")
  end

  test "links the main pages, the API, its OpenAPI description and the MCP server by absolute URLs" do
    get "/llms.txt"

    [ seasons_url, players_url, api_docs_url, api_v1_openapi_url, "http://www.example.com/mcp", sitemap_url ].each do |url|
      assert_includes response.body, url
    end
    assert_includes response.body, "rikkio（立大・立教大学。綴りは rikkio）"
  end

  test "lists every note for developers, with its summary as plain text" do
    get "/llms.txt"

    DeveloperDoc.all.each { |doc| assert_includes response.body, "[#{doc.title}](http://www.example.com#{doc.site_path})" }
    assert_no_match(/\]\((?!http)/, response.body) # no relative Markdown links left from the notes
    assert_no_match "**", response.body
  end
end
