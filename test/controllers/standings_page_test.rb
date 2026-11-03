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

  test "a 2021 season's standings page says its 勝ち点 are points, a draw half of one, and a usual season's doesn't" do
    season = Season.create!(year: 2021, term: "autumn")
    Game.create!(season:, team0: universities(:one), team1: universities(:two), played_on: Date.new(2021, 9, 18), game_number: 1,
      team0_score: 2, team1_score: 2, game_status: "試合終了")

    get standings_season_url(2021, "autumn")
    assert_select "p.muted", text: /1カード2試合.*勝ち1点・引分0.5点/m
    assert_select "table.standings-table td", text: "0.5"

    get standings_season_url(2026, "spring")
    assert_select "p.muted", text: /勝ち1点・引分0.5点/, count: 0
  end

  test "the records tab has each team's batting average and ERA, and says when box scores are missing" do
    player = Player.create!(scorebook_id: 1, university: universities(:one), name: "打者", enter_year: 2023, role: "選手")
    game = Game.where(season: seasons(:one)).order(:played_on).first
    BattingLine.create!(game:, player:, university: universities(:one), ab: 4, hits: 1)
    PitchingLine.create!(game:, player:, university: universities(:one), outs: 27, earned_runs: 3)

    get records_season_url(2026, "spring")

    assert_select "section.team-stats tbody tr", 1
    assert_select "section.team-stats tbody td", text: ".250"
    assert_select "section.team-stats tbody td", text: "3.00"
    assert_select "section.team-stats p.muted", text: /Alphaは2試合のうち1試合の成績です/
  end

  test "the standings API gives each team's stats from the box scores, and null with none" do
    player = Player.create!(scorebook_id: 1, university: universities(:one), name: "打者", enter_year: 2023, role: "選手")
    game = Game.where(season: seasons(:one)).order(:played_on).first
    BattingLine.create!(game:, player:, university: universities(:one), ab: 4, hits: 1, home_runs: 1)
    PitchingLine.create!(game:, player:, university: universities(:one), outs: 27, earned_runs: 3)

    get "/api/v1/seasons/2026/spring/standings"

    rows = response.parsed_body.index_by { |row| row["university"]["slug"] }
    assert_equal({ "games" => 1, "batting_average" => 0.25, "home_runs" => 1, "stolen_bases" => 0, "era" => 3.0, "fielding_errors" => 0 },
      rows["alpha"]["team_stats"])
    assert_nil rows["beta"]["team_stats"]
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

  test "the attendance columns start hidden, headings and figures alike, until the attendance is chosen" do
    get standings_season_url(2026, "spring")

    assert_select "th.sortable[data-cell-toggle-target=attendanceColumn][hidden]", 2
    assert_select "td[data-cell-toggle-target~=attendanceColumn][hidden]", 2 * css_select("table.standings-table tbody tr").size
    assert_select "th.sortable[data-cell-toggle-target=resultsColumn]:not([hidden])", SeasonsHelper::STANDINGS_COLUMNS.size - 2
  end

  test "the rate and the attendance sort by their values, not by the text shown" do
    Game.update_all(attendance: 12_000)

    get standings_season_url(2026, "spring")

    assert_select "td[data-sort-value='0.5']", text: ".500"
    assert_select "td[data-all='24,000'][data-sort-value='24000']", 2
  end

  test "teams level on both 勝ち点 and 勝率 share a place on the page and in the API" do
    # The setup's two games are one win each: alpha and beta are level.
    get standings_season_url(2026, "spring")

    assert_equal %w[1 1], css_select("table.standings-table tbody td.col-rank").map { |td| td.text.strip }

    get "/api/v1/seasons/2026/spring/standings"

    assert_equal [ 1, 1 ], response.parsed_body.map { |row| row["rank"] }
  end
end
