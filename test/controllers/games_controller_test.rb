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
end
