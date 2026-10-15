require "test_helper"

# A season whose games come from a club's history (SourceGameImport): only
# that club's games are on the site, so its standings are the printed table,
# and nothing is worked out from its games as if they were all of them.
class PrintedSourceSeasonsTest < ActionDispatch::IntegrationTest
  CITATION = "立教大学野球部 編『立教大学野球部史』（1981年）pp.38–42".freeze
  URL = "https://dl.ndl.go.jp/pid/12172714/1/42".freeze

  setup do
    Game.delete_all
    @alpha = universities(:one)
    @beta = universities(:two)
    @season = Season.create!(year: 1926, term: "spring", source_standings: {
      "citation" => CITATION, "url" => URL, "opponents" => %w[beta alpha], "self_mark" => "：",
      "rows" => [
        { "university" => "beta", "games" => 3, "wins" => 2, "losses" => 1, "draws" => 0, "points" => 1, "average" => ".667", "cells" => { "beta" => "：", "alpha" => "2" } },
        { "university" => "alpha", "games" => 3, "wins" => 1, "losses" => 2, "draws" => 0, "points" => 0, "average" => ".333", "cells" => { "beta" => "1", "alpha" => "：" } }
      ]
    })
    [ [ 1, 2, 0 ], [ 2, 0, 3 ], [ 3, 1, 4 ] ].each do |round, score0, score1|
      Game.create!(season: @season, team0: @alpha, team1: @beta, played_on: Date.new(1926, 4, 16 + round), game_number: round,
        team0_score: score0, team1_score: score1, game_status: "試合終了", source_citation: CITATION, source_url: URL,
        source_scoreboard: { "runs1Top" => score0.to_s, "runs1Bottom" => score1.to_s })
    end
  end

  test "the standings page shows the printed table with its source" do
    get standings_season_url(1926, "spring")

    assert_response :success
    assert_select "table.standings-table tbody tr", 2
    assert_select "table.standings-table tbody tr:first-child td", text: ".667"
    assert_select "a[href=?]", URL, text: CITATION
    assert_match "#{@beta.short_name} 2勝1敗", response.body
  end

  test "the standings API gives the printed rows in the printed order, with the source" do
    get "/api/v1/seasons/1926/spring/standings"

    rows = response.parsed_body
    assert_equal [ "beta", "alpha" ], rows.map { |row| row.dig("university", "slug") }
    assert_equal [ 2, 1, 1, 0.667, nil ], rows.first.values_at("wins", "losses", "points", "percentage", "runs_scored")
    assert_equal({ "citation" => CITATION, "url" => URL }, rows.first["source"])
  end

  test "the season page says only one club's games are here, and who led the printed table" do
    get season_url(1926, "spring")

    assert_match "このサイトに#{@alpha.short_name}の3試合だけがある（立教大学野球部 編『立教大学野球部史』より）。" \
      "同書の勝敗表では#{@beta.short_name}が首位（2勝1敗）。", response.body
  end

  test "works out no tags and no title odds from such a season's games" do
    assert @season.from_printed_sources?
    assert_empty SeasonTags.new(@season).tags
    assert_nil ChampionshipOdds.around(Game.find_by!(game_number: 3))
  end

  test "a season with such games but no printed table shows no standings" do
    @season.update!(source_standings: nil)

    get standings_season_url(1926, "spring")
    assert_response :success
    assert_select "table.standings-table", 0
    assert_match "出典に勝敗表がないため、順位表は載せていません。", response.body

    get "/api/v1/seasons/1926/spring/standings"
    assert_equal [], response.parsed_body
  end
end
