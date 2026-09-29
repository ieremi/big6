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

  test "the standings carry both attendance figures, with a button to switch" do
    get standings_season_url(2026, "spring")

    assert_response :success
    assert_select "button[data-action='cell-toggle#toggleWeekends'][data-shortcut=h]", text: /平日の試合をのぞく/
    assert_select "td[data-all='11,000'][data-weekend='15,000']", 2
    assert_select "td[data-all='33,000'][data-weekend='30,000']", 2
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
