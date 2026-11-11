require "test_helper"

# The 平日の試合をのぞく option on the pages and in the Web API.
class WeekendAttendanceControllerTest < ActionDispatch::IntegrationTest
  setup do
    @alpha = universities(:one)
    @beta = universities(:two)
    Game.delete_all
    { "2026-05-02" => 20_000, "2026-05-03" => 10_000, "2026-05-04" => 3_000 }.each_with_index do |(date, attendance), index|
      Game.create!(season: seasons(:one), team0: @alpha, team1: @beta, played_on: date, game_number: index + 1,
        team0_score: 2, team1_score: 1, game_status: "試合終了", attendance: attendance)
    end
  end

  test "the matchups table carries the weekend figures beside the others, with a button to show them" do
    get matchups_url

    assert_response :success
    assert_select "button[data-action='period-filter#toggleWeekends'][data-shortcut=h]", text: /平日の試合をのぞく/
    assert_select "a[data-attendance-avg-all='11,000'][data-attendance-avg-all-weekend='15,000'][data-attendance-sum-all-weekend='30,000']", 2
    assert_select "span[data-period-filter-target=rowAvg][data-attendance-all-weekend='15,000']"
    assert_select "span[data-period-filter-target=rowSum][data-attendance-all-weekend='30,000']"
  end

  test "the season's 観衆 tab gives each university's average with and without the weekday games, and each pair's games" do
    get attendance_season_url(2026, "spring")

    assert_response :success
    # 試合, 合計, 1試合平均, 土日の1試合平均: the season's, then each university's.
    assert_select "section.season-attendance tbody tr:first-child" do |rows|
      assert_equal %w[3 33,000 11,000 15,000], rows.first.css("td").map { |td| td.text.strip }
    end
    assert_select "section.university-attendance tbody tr", 2 do |rows|
      assert_equal %w[3 33,000 11,000 15,000], rows.first.css("td").drop(1).map { |td| td.text.strip }
    end
    assert_select "section.matchup-attendance td.result-cell a", text: "20,000/10,000/3,000", count: 2
    assert_select "section.matchup-attendance td.result-cell a br", 4
  end

  test "the matchup API counts the weekend games only when asked" do
    get "/api/v1/matchups/alpha/beta"
    assert_equal({ "average" => 11_000, "total" => 33_000 }, response.parsed_body["attendance"])

    get "/api/v1/matchups/alpha/beta", params: { exclude_weekdays: "true" }
    assert_equal({ "average" => 15_000, "total" => 30_000 }, response.parsed_body["attendance"])
  end

  test "the standings API counts the weekend games only when asked" do
    get "/api/v1/seasons/2026/spring/standings", params: { exclude_weekdays: 1 }

    row = response.parsed_body.find { |r| r["university"]["slug"] == "alpha" }
    assert_equal [ 30_000, 15_000 ], row.values_at("attendance_total", "average_attendance")

    get "/api/v1/seasons/2026/spring/standings", params: { exclude_weekdays: "false" }
    row = response.parsed_body.find { |r| r["university"]["slug"] == "alpha" }
    assert_equal [ 33_000, 11_000 ], row.values_at("attendance_total", "average_attendance")
  end
end
