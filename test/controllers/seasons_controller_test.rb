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
    assert_match(/日本の1人あたりGDP：[\d,]+ USD\/y/, response.body)
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

  private

  def create_season_with_game(year, term, played_on)
    season = Season.create!(year: year, term: term)
    Game.create!(season: season, team0: universities(:one), team1: universities(:two), played_on: played_on, game_number: 1)
  end
end
