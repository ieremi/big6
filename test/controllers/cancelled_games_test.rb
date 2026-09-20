require "test_helper"

# How a cancelled (中止) game shows up: the 9/20 game of a series that is replayed
# on 9/22 under the same round number.
class CancelledGamesTest < ActionDispatch::IntegrationTest
  setup do
    @alpha = universities(:one)
    @beta = universities(:two)
    @season = Season.create!(year: 2027, term: "spring")
    @played = create_game("2027-05-01", 1, game_status: "試合終了", team0_score: 5, team1_score: 12, attendance: 4000)
    @cancelled = create_game("2027-05-02", 2, game_status: "中止")
    @replay = create_game("2027-05-04", 2, game_status: "試合終了", team0_score: 7, team1_score: 6, attendance: 3000)
  end

  def create_game(day, number, **attributes)
    Game.create!({ season: @season, team0: @alpha, team1: @beta, played_on: day, game_number: number }.merge(attributes))
  end

  def json
    JSON.parse(response.body)
  end

  # ---- the game's page

  test "a cancelled game's page says it was cancelled" do
    @replay.destroy

    get matchup_game_url("alpha", "beta", 2027, "spring", 2)

    assert_response :success
    assert_select "p.muted", text: /この試合は中止になりました/
    assert_select ".score", text: "中止"
  end

  test "the round number of a cancelled game and its replay is the replay's page" do
    get matchup_game_url("alpha", "beta", 2027, "spring", 2)

    assert_response :success
    assert_select "p.muted", text: /この試合は中止になりました/, count: 0
    assert_match "2027-05-04", response.body
  end

  # ---- lists

  test "the game list shows a cancelled game as text, with no link to a page, and keeps its round" do
    get games_url, params: { filtered: 1, terms: %w[spring], university_ids: [ @alpha.id ], start_year: 2027, end_year: 2027 }

    assert_response :success
    assert_select "span.game-cancelled .score", text: "中止", count: 1
    assert_select "span.game-cancelled a", 0
    assert_select "tbody tr", 3
    assert_select "tbody td", text: "2回戦", count: 2 # the cancelled game and its replay
    assert_select "a[href=?]", matchup_game_path("alpha", "beta", 2027, "spring", 1)
  end

  test "the season page lists it the same way" do
    get season_url(2027, "spring")

    assert_response :success
    assert_select "[data-mode=card] span.game-cancelled .score", text: "中止", count: 1
    assert_select "[data-mode=card] span.game-cancelled a", 0
  end

  # ---- the Web API

  test "the API says which games were cancelled, and finds the replay by the round they share" do
    get api_v1_games_url, params: { start_year: 2027, end_year: 2027 }

    assert_equal [ false, true, false ], json["games"].map { |game| game["cancelled"] }
    assert_equal [ nil, nil ], json["games"][1].values_at("team0", "team1").map { |team| team["score"] }

    get "/api/v1/games/2027/spring/alpha/beta/2"

    assert_equal [ "2027-05-04", false, 7 ], [ json["played_on"], json["cancelled"], json["team0"]["score"] ]
  end

  # ---- the calendar

  test "a cancelled game is in the calendar as cancelled, so a subscriber sees it go" do
    get season_path(2027, "spring", format: :ics)

    events = response.body.split("BEGIN:VEVENT").drop(1)
    cancelled = events.find { |event| event.include?("game-#{@cancelled.id}@big6") }
    assert_includes cancelled, "STATUS:CANCELLED"
    assert_includes cancelled, "SUMMARY:【中止】Alpha vs Beta②"
    assert_equal 1, events.count { |event| event.include?("STATUS:CANCELLED") }
  end
end
