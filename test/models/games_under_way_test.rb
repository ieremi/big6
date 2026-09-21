require "test_helper"

# A game under way has a score, but not a final one: it must not count as a win, a
# loss or a draw, nor add its crowd, until it is over.
class GamesUnderWayTest < ActiveSupport::TestCase
  setup do
    @alpha = universities(:one)
    @beta = universities(:two)
    @season = Season.create!(year: 2013, term: "spring")
    Game.create!(season: @season, team0: @alpha, team1: @beta, played_on: "2013-05-01", game_number: 1, game_status: "finished", team0_score: 3, team1_score: 1, attendance: 4000)
    @live = Game.create!(season: @season, team0: @beta, team1: @alpha, played_on: "2013-05-02", game_number: 2, game_status: "in_progress", team0_score: 5, team1_score: 0, attendance: 3000)
  end

  def finish_the_live_game
    @live.update!(game_status: "finished")
  end

  test "standings leave out a game under way, and count it once it is over" do
    rows = ->(standings) { standings.rows.to_h { |row| [ row.university.slug, [ row.wins, row.losses, row.games, row.attendance_total ] ] } }

    assert_equal [ 1, 0, 1, 4000 ], rows.call(Standings.new(@season))["alpha"]
    assert_equal [ 0, 1, 1, 4000 ], rows.call(Standings.new(@season))["beta"]

    finish_the_live_game

    assert_equal [ 1, 1, 2, 7000 ], rows.call(Standings.new(@season.reload))["alpha"]
  end

  test "a team's record leaves out a game under way" do
    record = TeamRecord.new(@alpha)

    assert_equal [ 1, 0, 0 ], [ record.wins(season_id: @season.id), record.losses(season_id: @season.id), record.draws(season_id: @season.id) ]

    finish_the_live_game

    record = TeamRecord.new(@alpha)
    assert_equal [ 1, 1 ], [ record.wins(season_id: @season.id), record.losses(season_id: @season.id) ]
  end

  test "a matchup leaves out a game under way" do
    assert_equal [ 1, 0, 4000 ], [ Matchup.new(@alpha, @beta).wins(@alpha), Matchup.new(@alpha, @beta).wins(@beta), Matchup.new(@alpha, @beta).total_attendance ]

    finish_the_live_game

    assert_equal [ 1, 1 ], [ Matchup.new(@alpha, @beta).wins(@alpha), Matchup.new(@alpha, @beta).wins(@beta) ]
  end

  test "the attendance trend leaves out a game under way" do
    total = ->(season) { SeasonAttendanceTrend.new(season).current_points.last.cumulative }

    assert_equal 4000, total.call(@season)

    finish_the_live_game

    assert_equal 7000, total.call(@season.reload)
  end
end
