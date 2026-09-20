require "test_helper"

class GamesControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get games_url
    assert_response :success
  end

  # The fixtures already have alpha v beta in each of the two seasons; add a third
  # university with a game against each, so all three pairings exist.
  def setup_three_universities
    @alpha = universities(:one)
    @beta = universities(:two)
    @gamma = University.create!(name: "Gamma University", short_name: "Gamma", slug: "gamma", position: 3)
    Game.create!(season: seasons(:one), team0: @beta, team1: @gamma, played_on: "2026-05-02", game_number: 2)
    Game.create!(season: seasons(:one), team0: @gamma, team1: @alpha, played_on: "2026-05-09", game_number: 3)
  end

  def search(university_ids, mode)
    get games_url, params: { filtered: 1, university_mode: mode, university_ids: university_ids.map(&:id), terms: %w[spring autumn] }
    assert_response :success
    assigns_total = css_select("p.muted").map(&:text).find { |text| text.include?("試合中") }
    assigns_total ? assigns_total[/(\d+)試合中/, 1].to_i : 0
  end

  test "searching with AND finds the games between the two selected universities" do
    setup_three_universities

    assert_equal 2, search([ @alpha, @beta ], "and") # the alpha v beta game of each season
    assert_equal 1, search([ @beta, @gamma ], "and")
  end

  test "searching with AND for three universities finds nothing, since a game has two teams" do
    setup_three_universities

    assert_equal 0, search([ @alpha, @beta, @gamma ], "and")
  end

  test "searching with OR finds every game any selected university played" do
    setup_three_universities

    assert_equal 4, search([ @alpha, @beta, @gamma ], "or")
    assert_equal 2, search([ @gamma ], "or")
  end

  test "AND with a single university (or the same one twice) is the same as OR" do
    setup_three_universities

    assert_equal 3, search([ @alpha ], "and")
    assert_equal 3, search([ @alpha, @alpha ], "and")
  end

  test "the calendar feed applies the same AND rule" do
    setup_three_universities

    get games_url(format: :ics), params: { filtered: 1, university_mode: "and", university_ids: [ @alpha.id, @beta.id, @gamma.id ], terms: %w[spring autumn] }

    assert_response :success
    assert_no_match(/BEGIN:VEVENT/, response.body)
  end

  # ---- sorting the table by any column

  def sort_games
    @alpha = universities(:one)
    @beta = universities(:two)
    Game.delete_all
    @first = Game.create!(season: seasons(:one), team0: @alpha, team1: @beta, played_on: "2026-05-02", game_number: 1, attendance: 3000)
    @second = Game.create!(season: seasons(:one), team0: @alpha, team1: @beta, played_on: "2026-05-03", game_number: 2, attendance: nil)
    @third = Game.create!(season: seasons(:two), team0: @beta, team1: @alpha, played_on: "2026-09-12", game_number: 1, attendance: 9000)
    @fourth = Game.create!(season: seasons(:two), team0: @alpha, team1: @beta, played_on: "2026-09-13", game_number: 3, attendance: 500)
  end

  # The dates of the games listed, in order (the second column: after the season).
  def listed_dates(path = games_url, **params)
    get path, params: { filtered: 1, terms: %w[spring autumn], university_ids: [ @alpha.id ] }.merge(params)
    assert_response :success
    css_select("tbody tr").map { |row| row.css("td")[1].text }
  end

  test "games sort by date, either way, which is the order they come in" do
    sort_games

    assert_equal %w[2026-05-02 2026-05-03 2026-09-12 2026-09-13], listed_dates
    assert_equal %w[2026-05-02 2026-05-03 2026-09-12 2026-09-13], listed_dates(sort: "date", direction: "asc")
    assert_equal %w[2026-09-13 2026-09-12 2026-05-03 2026-05-02], listed_dates(sort: "date", direction: "desc")
  end

  test "games sort by round, with the earlier date first among equal rounds" do
    sort_games

    assert_equal %w[2026-05-02 2026-09-12 2026-05-03 2026-09-13], listed_dates(sort: "round", direction: "asc")
    assert_equal %w[2026-09-13 2026-05-03 2026-05-02 2026-09-12], listed_dates(sort: "round", direction: "desc")
  end

  test "games sort by attendance, and those with none come last whichever way" do
    sort_games

    assert_equal %w[2026-09-13 2026-05-02 2026-09-12 2026-05-03], listed_dates(sort: "attendance", direction: "asc")
    assert_equal %w[2026-09-12 2026-05-02 2026-09-13 2026-05-03], listed_dates(sort: "attendance", direction: "desc")
  end

  test "games still sort by season and by card, and ignore a sort they don't know" do
    sort_games

    assert_equal %w[2026-09-12 2026-09-13 2026-05-02 2026-05-03], listed_dates(sort: "season", direction: "desc")
    assert_equal %w[2026-05-02 2026-05-03 2026-09-12 2026-09-13], listed_dates(sort: "card")
    assert_equal %w[2026-05-02 2026-05-03 2026-09-12 2026-09-13], listed_dates(sort: "bogus", direction: "desc")
  end

  test "the headings are sort links with a capital-letter shortcut each" do
    sort_games
    get games_url, params: { filtered: 1, terms: %w[spring autumn], university_ids: [ @alpha.id ] }

    { "season" => "S", "date" => "D", "round" => "N", "card" => "C", "attendance" => "A" }.each do |key, shortcut|
      assert_select "th.sortable a[data-shortcut=?][href*=?]", shortcut, "sort=#{key}"
    end
    assert_select "th.sortable", 5
  end

  test "the date heading counts as sorted when nothing is asked for, and a second click reverses a sort" do
    sort_games
    get games_url, params: { filtered: 1, terms: %w[spring autumn], university_ids: [ @alpha.id ] }

    assert_select "th.sortable.sorted-asc a[data-shortcut=D][href*=?]", "direction=desc"
    assert_select "th.sortable.sorted-asc", 1

    get games_url, params: { filtered: 1, terms: %w[spring autumn], university_ids: [ @alpha.id ], sort: "attendance", direction: "desc" }

    assert_select "th.sortable.sorted-desc a[data-shortcut=A][href*=?]", "direction=asc"
    assert_select "th.sortable.sorted-asc", 0
    assert_select "th[aria-sort=descending]", 1
  end

  test "the first click on attendance is the biggest first, and the other columns start ascending" do
    sort_games
    get games_url, params: { filtered: 1, terms: %w[spring autumn], university_ids: [ @alpha.id ] }

    assert_select "th a[data-shortcut=A][href*=?]", "direction=desc"
    assert_select "th a[data-shortcut=N][href*=?]", "direction=asc"
    assert_select "th a[data-shortcut=C][href*=?]", "direction=asc"
  end

  test "a heading's link keeps the search but starts again at the first page" do
    sort_games
    get games_url, params: { filtered: 1, terms: %w[spring autumn], university_ids: [ @alpha.id ], page: 2 }

    assert_select "th a[data-shortcut=N][href*=?]", "university_ids"
    assert_select "th a[data-shortcut=N][href*=?]", "page=", false
  end

  test "a matchup's games sort by the same columns" do
    sort_games
    dates = lambda do |**params|
      get "/matchups/alpha/beta", params: params
      assert_response :success
      css_select("tbody tr").map { |row| row.css("td")[1].text }
    end

    assert_equal %w[2026-05-02 2026-05-03 2026-09-12 2026-09-13], dates.call(sort: "date")
    assert_equal %w[2026-09-13 2026-09-12 2026-05-03 2026-05-02], dates.call(sort: "date", direction: "desc")
    assert_equal %w[2026-05-02 2026-09-12 2026-05-03 2026-09-13], dates.call(sort: "round")
    assert_equal %w[2026-09-12 2026-05-02 2026-09-13 2026-05-03], dates.call(sort: "attendance", direction: "desc")
    assert_equal %w[2026-09-13 2026-05-02 2026-09-12 2026-05-03], dates.call(sort: "attendance")
  end

  test "no two elements on the games page share a shortcut key, the headings' keys included" do
    sort_games
    University.create!(name: "Rikkio University", short_name: "Rikkio", slug: "rikkio", position: 4) # initial R, as the real league has

    get games_url, params: { filtered: 1, terms: %w[spring autumn], university_ids: University.pluck(:id) }

    keys = css_select("[data-shortcut]").map { |element| element["data-shortcut"] }
    assert_operator keys.size, :>, 10
    assert_equal [], keys.tally.select { |_, count| count > 1 }.keys
  end
end
