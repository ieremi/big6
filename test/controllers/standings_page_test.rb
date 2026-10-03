require "test_helper"

# Runs scored and allowed (得点・失点) on the standings page and in the Web API,
# and sorting the standings table by its figures.
class StandingsPageTest < ActionDispatch::IntegrationTest
  setup do
    Game.delete_all
    [ [ 5, 2 ], [ 1, 3 ] ].each_with_index do |(team0_score, team1_score), index|
      Game.create!(season: seasons(:one), team0: universities(:one), team1: universities(:two), played_on: Date.new(2026, 5, 2) + index,
        game_number: index + 1, team0_score: team0_score, team1_score: team1_score, game_status: "試合終了")
    end
  end

  test "the standings page has a 得点 and a 失点 column for each team" do
    get standings_season_url(2026, "spring")

    headings = css_select("table.standings-table thead th").map { |th| th.text.split.first }
    scored, allowed = headings.index("得点"), headings.index("失点")
    assert_equal scored + 1, allowed
    alpha_row = css_select("table.standings-table tbody tr").find { |tr| tr.text.include?(universities(:one).short_name) }
    assert_equal %w[6 5], alpha_row.css("td").to_a.values_at(scored, allowed).map { |td| td.text.strip }
  end

  test "the standings API gives each team's runs scored and allowed" do
    get "/api/v1/seasons/2026/spring/standings"

    alpha = response.parsed_body.find { |row| row["university"]["slug"] == "alpha" }
    assert_equal [ 6, 5 ], alpha.values_at("runs_scored", "runs_allowed")
  end

  test "the standings table sorts in the browser by its figures, not by the results against each opponent" do
    get standings_season_url(2026, "spring")

    assert_select "table.standings-table[data-controller~=sortable-table]"
    sortable = css_select("table.standings-table th.sortable button[data-action='sortable-table#sort']").map { |button| button.text.split.first }
    assert_equal SeasonsHelper::STANDINGS_COLUMNS.keys, sortable
    assert_select "th.sortable[data-cell-toggle-target=resultsColumn] button[data-shortcut=S][data-sortable-table-first-param=desc]", text: /得点/
    assert_select "th.sortable[data-cell-toggle-target=resultsColumn] button[data-shortcut=E][data-sortable-table-first-param=asc]", text: /失点/
    assert_select "th.sortable[data-cell-toggle-target=attendanceColumn] button[data-shortcut=T]", text: /総観衆/
    assert_select "th.col-rank:not(.sortable)"
  end

  test "the rate and the attendance sort by their values, not by the text shown" do
    Game.update_all(attendance: 12_000)

    get standings_season_url(2026, "spring")

    assert_select "td[data-sort-value='0.5']", text: ".500"
    assert_select "td[data-all='24,000'][data-sort-value='24000']", 2
  end
end
