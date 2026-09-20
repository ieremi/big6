require "test_helper"

class SeasonsControllerTest < ActionDispatch::IntegrationTest
  test "index lists seasons that have games as links with their game count" do
    get seasons_url

    assert_response :success
    assert_select "a[href=?]", season_path(2026, "spring"), text: "2026年春季"
    assert_select "a[href=?]", standings_season_path(2026, "spring")
    assert_match "1試合", response.body
  end

  test "index no longer shows total attendance" do
    get seasons_url

    assert_no_match "総観衆", response.body
  end

  test "index filters seasons by tag across all seasons" do
    get seasons_url, params: { tags: [ SeasonTags::LABELS.first ] }

    assert_response :success
  end

  test "index ignores unknown tag values" do
    get seasons_url, params: { tags: [ "not-a-tag" ] }

    assert_response :success
    assert_select "a[href=?]", season_path(2026, "spring")
  end

  test "show lists the Prime Minister and GDP per capita for the season" do
    create_season_with_game(1995, "spring", "1995-04-08")

    get season_url(1995, "spring")

    assert_response :success
    assert_match "内閣総理大臣：村山富市", response.body
    assert_match "日本の1人あたりGDP：44,000 USD/y", response.body
  end

  test "show joins Prime Ministers with an arrow when the office changed during the season" do
    create_season_with_game(2001, "spring", "2001-04-14")
    Game.create!(season: Season.find_by!(year: 2001, term: "spring"), team0: universities(:two), team1: universities(:one),
      played_on: "2001-06-03", game_number: 2)

    get season_url(2001, "spring")

    assert_match "内閣総理大臣：森喜朗 → 小泉純一郎", response.body
  end

  test "show omits GDP per capita for seasons before the World Bank series starts" do
    create_season_with_game(1950, "spring", "1950-04-15")

    get season_url(1950, "spring")

    assert_response :success
    assert_match "内閣総理大臣：吉田茂", response.body
    assert_no_match "1人あたりGDP", response.body
  end

  # ---- narrowing the games to universities

  # Week 1: alpha v beta, week 2: beta v gamma, week 3: alpha v gamma (two games).
  def create_three_week_season
    @alpha = universities(:one)
    @beta = universities(:two)
    @gamma = University.create!(name: "Gamma University", short_name: "Gamma", slug: "gamma", position: 3)
    season = Season.create!(year: 2003, term: "spring")
    Game.create!(season: season, team0: @alpha, team1: @beta, played_on: "2003-04-05", game_number: 1)
    Game.create!(season: season, team0: @beta, team1: @gamma, played_on: "2003-04-12", game_number: 1)
    Game.create!(season: season, team0: @alpha, team1: @gamma, played_on: "2003-04-19", game_number: 1)
    Game.create!(season: season, team0: @alpha, team1: @gamma, played_on: "2003-04-20", game_number: 2)
  end

  def week_headings
    css_select("h2.week-heading").map(&:text)
  end

  # The played-on dates in the by-card view, which lists each game once.
  def listed_dates
    css_select("[data-mode=card] tbody tr td:first-child").map(&:text)
  end

  test "show lists every week and game when no university is chosen" do
    create_three_week_season

    get season_url(2003, "spring")

    assert_equal [ "第1週", "第2週", "第3週" ], week_headings
    assert_equal %w[2003-04-05 2003-04-12 2003-04-19 2003-04-20], listed_dates
    assert_select "input[name='university_ids[]']", 3
    assert_select "input[name='university_ids[]'][checked]", 0
    assert_select "p.muted", text: /の試合のみ/, count: 0
  end

  test "show narrows the games to a university, keeping the weeks' own numbers" do
    create_three_week_season

    get season_url(2003, "spring"), params: { university_ids: [ @gamma.id ] }

    assert_equal [ "第2週", "第3週" ], week_headings # week 1 has no Gamma game, and week 3 is still week 3
    assert_equal %w[2003-04-12 2003-04-19 2003-04-20], listed_dates
    assert_select "input[name='university_ids[]'][checked]", 1
    assert_select "input#university_ids_#{@gamma.id}[checked]"
    assert_select "p.muted", text: /Gamma.*の試合のみ：3試合（全4試合）/m
  end

  test "show with several universities has the games any of them played" do
    create_three_week_season

    get season_url(2003, "spring"), params: { university_ids: [ @alpha.id, @beta.id ] }

    assert_equal [ "第1週", "第2週", "第3週" ], week_headings
    assert_equal 4, listed_dates.size

    get season_url(2003, "spring"), params: { university_ids: [ @beta.id ] }

    assert_equal [ "第1週", "第2週" ], week_headings
  end

  test "show ignores a university that did not play that season" do
    create_three_week_season
    outsider = University.create!(name: "Delta University", short_name: "Delta", slug: "delta", position: 4)

    get season_url(2003, "spring"), params: { university_ids: [ outsider.id, 0 ] }

    assert_equal [ "第1週", "第2週", "第3週" ], week_headings
    assert_select "input[name='university_ids[]']", 3 # only those that played are offered
    assert_select "p.muted", text: /の試合のみ/, count: 0
  end

  test "show puts the chosen universities into the calendar links, and the calendar has only their games" do
    create_three_week_season

    get season_url(2003, "spring"), params: { university_ids: [ @gamma.id ] }
    assert_select "a[href=?]", season_path(2003, "spring", format: :ics, university_ids: [ @gamma.id ]), text: "カレンダーに追加 (.ics)"

    get season_path(2003, "spring", format: :ics)
    assert_equal 4, response.body.scan("BEGIN:VEVENT").size

    get season_path(2003, "spring", format: :ics, university_ids: [ @gamma.id ])
    assert_equal 3, response.body.scan("BEGIN:VEVENT").size

    get season_path(2003, "spring", format: :ics, university_ids: [ @beta.id ])
    assert_equal 2, response.body.scan("BEGIN:VEVENT").size
  end

  test "show's calendar links have no filter when none is chosen" do
    create_three_week_season

    get season_url(2003, "spring")

    assert_select "a[href=?]", season_path(2003, "spring", format: :ics), text: "カレンダーに追加 (.ics)"
  end

  test "show gives each university's checkbox its initial as a shortcut, none shared with another element" do
    create_three_week_season
    University.create!(name: "Rikkio University", short_name: "Rikkio", slug: "rikkio", position: 4).then do |rikkio|
      Game.create!(season: Season.find_by!(year: 2003, term: "spring"), team0: rikkio, team1: @alpha, played_on: "2003-04-26", game_number: 1)
    end

    get season_url(2003, "spring")

    assert_select "label[data-shortcut=R][data-shortcut-label=?]", "Rikkioを切替"
    keys = css_select("[data-shortcut]").map { |element| element["data-shortcut"] }
    assert_equal [], keys.tally.select { |_, count| count > 1 }.keys
  end

  private

  def create_season_with_game(year, term, played_on)
    season = Season.create!(year: year, term: term)
    Game.create!(season: season, team0: universities(:one), team1: universities(:two), played_on: played_on, game_number: 1)
  end
end
