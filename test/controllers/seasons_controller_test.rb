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
end
