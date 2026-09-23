require "test_helper"

# How a cancelled (中止) game shows up: the 9/20 game of a series that is replayed
# on 9/22 under the same round number.
class CancelledGamesTest < ActionDispatch::IntegrationTest
  setup do
    @alpha = universities(:one)
    @beta = universities(:two)
    @season = Season.create!(year: 2027, term: "spring")
    @played = create_game("2027-05-01", 1, game_status: "試合終了", team0_score: 5, team1_score: 12, attendance: 4000)
    @cancelled = create_game("2027-05-02", nil, game_status: "中止")
    @replay = create_game("2027-05-04", 2, game_status: "試合終了", team0_score: 7, team1_score: 6, attendance: 3000)
  end

  def create_game(day, number, **attributes)
    Game.create!({ season: @season, team0: @alpha, team1: @beta, played_on: day, game_number: number }.merge(attributes))
  end

  def json
    JSON.parse(response.body)
  end

  # ---- the game's page

  test "a cancelled game has no page of its own: its round number is its replay's" do
    get matchup_game_url("alpha", "beta", 2027, "spring", 2)

    assert_response :success
    assert_match "2027-05-04", response.body # the replay
    assert_select ".score", text: "中止", count: 0
  end

  test "without the replay there is no game to show for that round number" do
    @replay.destroy

    get matchup_game_url("alpha", "beta", 2027, "spring", 2)

    assert_response :not_found
  end

  # ---- lists

  test "the game list shows a cancelled game as text, with no link to a page and no round" do
    get games_url, params: { filtered: 1, terms: %w[spring], university_ids: [ @alpha.id ], start_year: 2027, end_year: 2027 }

    assert_response :success
    assert_select "span.game-cancelled .score", text: "中止", count: 1
    assert_select "span.game-cancelled a", 0
    assert_select "tbody tr", 3
    assert_select "tbody td", text: "2回戦", count: 1 # the replay
    assert_select "tbody td", text: "—", count: 1 # the cancelled game has no round
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
    assert_includes cancelled, "SUMMARY:【中止】Alpha vs Beta\r\n" # no round number to add
    assert_includes cancelled, "DESCRIPTION:2027年春季\r\n"
    assert_equal 1, events.count { |event| event.include?("STATUS:CANCELLED") }
  end

  # ---- counts: a cancelled game is listed but is not a game held

  test "a matchup's game count counts its games by status" do
    get "/matchups/alpha/beta/2027/spring"

    assert_select "p.muted", text: "終了2・中止1"
  end

  test "a matchup with no cancelled games leaves 中止 out of the count" do
    @cancelled.destroy

    get "/matchups/alpha/beta/2027/spring"

    assert_select "p.muted", text: "終了2"
  end

  test "the matchup page marks each row with its status, so the count for a chosen period can be by status" do
    get "/matchups/alpha/beta"

    assert_response :success
    assert_select "tr[data-period-filter-target=gameRow][data-status=cancelled]", minimum: 1
    assert_select "tr[data-period-filter-target=gameRow][data-status=finished]", minimum: 1
  end

  test "a team's game list counts its games by status" do
    get team_season_browse_url("alpha", 2027, "spring")

    assert_select "p.muted", text: "終了2・中止1"
  end

  test "the game search counts its games by status, and pages by the rows it lists" do
    get games_url, params: { filtered: 1, terms: %w[spring], university_ids: [ @alpha.id ], start_year: 2027, end_year: 2027 }

    assert_select "p.muted", text: /\A\s*全3件（終了2・中止1）中 1–3件を表示\s*\z/
    assert_select "tbody tr", 3
  end

  test "the seasons list counts the games held" do
    get seasons_url

    assert_select "li", text: /2027年春季.*\(2試合\)/m
  end

  test "a team's list of seasons counts the games held" do
    get team_browse_url("alpha")

    assert_select "li", text: /2027年春季.*\(2試合\)/m
  end

  test "the season page's count of a university's games leaves out the cancelled one" do
    get season_url(2027, "spring"), params: { university_ids: [ @alpha.id ] }

    assert_select "p.muted", text: /の試合のみ：2試合（全2試合）/
  end

  # ---- sitemap

  test "the sitemap lists the round number a cancelled game shares with its replay once, and not the cancelled game" do
    get sitemap_url(format: :xml)

    assert_response :success
    locs = response.body.scan(%r{<loc>([^<]*)</loc>}).flatten
    assert_equal 1, locs.count { |loc| loc.end_with?("/matchups/alpha/beta/2027/spring/2") }
    assert_equal locs.uniq.size, locs.size
  end
end
