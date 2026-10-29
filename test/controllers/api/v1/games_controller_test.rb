require "test_helper"

class Api::V1::GamesControllerTest < ActionDispatch::IntegrationTest
  test "gives the source of a game taken from a printed source, and its line score" do
    games(:one).update!(source_citation: "立教大学野球部 編『立教大学野球部史』（1981年）pp.29–31", source_url: "https://dl.ndl.go.jp/pid/12172714/1/37",
      source_scoreboard: { "stadium" => "池袋", "runs1Top" => "1", "runs1Bottom" => "0" })

    get "/api/v1/games/2026/spring/alpha/beta/1"

    assert_equal({ "citation" => "立教大学野球部 編『立教大学野球部史』（1981年）pp.29–31", "url" => "https://dl.ndl.go.jp/pid/12172714/1/37" }, response.parsed_body["source"])
    assert_equal [ "池袋", { "top" => "1", "bottom" => "0" } ], [ response.parsed_body.dig("scoreboard", "stadium"), response.parsed_body.dig("scoreboard", "innings", "1") ]
  end

  test "names a game outside the league's table by its playoff, and others by none" do
    games(:one).update!(playoff: "3位決定戦", counted_in_stats: false)

    get "/api/v1/games/2026/spring/alpha/beta/1"
    assert_equal [ 1, "3位決定戦" ], response.parsed_body.values_at("round", "playoff")

    get "/api/v1/games?start_year=2026&end_year=2026"
    assert response.parsed_body["games"].all? { |game| game.key?("playoff") }
  end

  test "the game page reads a playoff by its name in place of its round" do
    games(:one).update!(playoff: "3位決定戦", counted_in_stats: false)

    get "/matchups/alpha/beta/2026/spring/1"

    assert_response :success
    assert_select "title", /3位決定戦/
    assert_select "p.muted", text: /3位決定戦/
  end

  test "gives no source for a Scorebook game" do
    get "/api/v1/games?start_year=2026&end_year=2026"

    assert response.parsed_body["games"].any?
    assert response.parsed_body["games"].all? { |game| game.key?("source") && game["source"].nil? }
  end
end
