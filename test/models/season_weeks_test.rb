require "test_helper"

class SeasonWeeksTest < ActiveSupport::TestCase
  setup do
    @alpha = universities(:one)
    @beta = universities(:two)
    @gamma = University.create!(name: "Gamma University", short_name: "Gamma", slug: "gamma", position: 3)
    season = Season.create!(year: 2003, term: "spring")
    Game.create!(season: season, team0: @alpha, team1: @beta, played_on: "2003-04-05", game_number: 1)
    Game.create!(season: season, team0: @beta, team1: @gamma, played_on: "2003-04-12", game_number: 1)
    Game.create!(season: season, team0: @alpha, team1: @gamma, played_on: "2003-04-19", game_number: 1)
    @weeks = SeasonWeeks.new(season.games.includes(:team0, :team1).order(:played_on, :game_number))
  end

  test "weeks_with no universities is every week" do
    assert_equal [ 1, 2, 3 ], @weeks.weeks_with(nil).map(&:number)
    assert_equal [ 1, 2, 3 ], @weeks.weeks_with([]).map(&:number)
  end

  test "weeks_with universities keeps the weeks in which one of them played, under their own numbers" do
    assert_equal [ 2, 3 ], @weeks.weeks_with([ @gamma.id ]).map(&:number)
    assert_equal [ 1, 3 ], @weeks.weeks_with([ @alpha.id ]).map(&:number)
    assert_equal [ 1, 2, 3 ], @weeks.weeks_with([ @alpha.id, @beta.id ]).map(&:number)
  end

  test "weeks_with leaves out the series and games the universities were not in, and does not change the weeks" do
    week = @weeks.weeks_with([ @beta.id ]).find { |w| w.number == 2 }

    assert_equal 1, week.series.size
    assert_equal [ Date.new(2003, 4, 12) ], week.games.map(&:played_on)
    assert_equal [ 1, 2, 3 ], @weeks.weeks.map(&:number)
    assert_equal 1, @weeks.weeks.first.series.size
  end
end
