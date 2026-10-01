require "test_helper"

# The MCP server at /mcp (Big6Mcp), spoken to the way an AI assistant does.
class McpTest < ActionDispatch::IntegrationTest
  def rpc(method, params = nil, id: 1)
    post "/mcp", params: { jsonrpc: "2.0", id: id, method: method, params: params }.compact.to_json,
      headers: { "CONTENT_TYPE" => "application/json", "ACCEPT" => "application/json, text/event-stream" }
    assert_response :success
    response.parsed_body
  end

  def call_tool(name, arguments)
    rpc("tools/call", { name: name, arguments: arguments })["result"]
  end

  def tools
    rpc("tools/list").dig("result", "tools")
  end

  test "introduces itself with how to use the tools" do
    result = rpc("initialize", { protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "test", version: "1" } })["result"]

    assert_equal "big6", result.dig("serverInfo", "name")
    assert_match "search_players", result["instructions"]
    assert result.dig("capabilities", "tools")
  end

  test "has one read-only tool for each operation of the OpenAPI description" do
    operation_ids = Api::V1::OpenapiController.spec["paths"].values.flat_map(&:values).map { |operation| operation["operationId"].underscore }

    assert_equal operation_ids.sort, tools.map { |tool| tool["name"] }.sort
    tools.each do |tool|
      assert_equal [ true, false ], tool["annotations"].values_at("readOnlyHint", "destructiveHint"), tool["name"]
    end
  end

  test "a tool takes the operation's parameters, the path ones required, with references filled in" do
    game = tools.find { |tool| tool["name"] == "get_game" }

    assert_equal %w[round team0 team1 term year], game.dig("inputSchema", "required").sort
    assert_equal %w[waseda keio meiji hosei tokyo rikkio], game.dig("inputSchema", "properties", "team0", "enum")
    assert_no_match "$ref", game.to_json
  end

  test "a tool answers with the API's JSON, its arguments put in the path and the query" do
    result = call_tool("get_season", { year: 2026, term: "spring" })

    assert_equal false, result["isError"]
    assert_equal "2026年春季", result.dig("structuredContent", "title")
    assert_equal JSON.parse(result.dig("content", 0, "text")), result["structuredContent"]

    get "/api/v1/seasons/2026/spring"
    assert_equal response.parsed_body, result["structuredContent"]
  end

  test "a list argument goes into the query as the API's []-named parameter" do
    rikkio = University.create!(name: "立教大学", short_name: "立大", slug: "rikkio", position: 15)
    waseda = University.create!(name: "早稲田大学", short_name: "早大", slug: "waseda", position: 13)
    Player.create!(scorebook_id: 1, university: rikkio, name: "落合 智哉", enter_year: 2023, role: "選手", enrollment_status: 1)
    Player.create!(scorebook_id: 2, university: waseda, name: "落合 博満", enter_year: 2023, role: "選手", enrollment_status: 1)

    result = call_tool("search_players", { q: "落合", university: [ "rikkio" ] })

    assert_equal [ 1 ], result.dig("structuredContent", "players").map { |player| player["id"] }
  end

  test "arguments outside the tool's input schema are refused before the API is called" do
    result = call_tool("search_players", { university: [ "nowhere" ] })

    assert_equal true, result["isError"]
  end

  test "what the API can't find is an error result" do
    result = call_tool("get_player", { id: 1 })

    assert_equal true, result["isError"]
    assert_equal({ "error" => "not found" }, result["structuredContent"])
  end
end
