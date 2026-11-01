require "test_helper"

class SeasonHomeRunsTest < ActiveSupport::TestCase
  setup do
    Game.delete_all
    @alpha, @beta = universities(:one), universities(:two)
    @player = Player.create!(scorebook_id: 1, university: @alpha, name: "打者", enter_year: 2023, role: "選手")
  end

  # A season over, its games' box scores with these home runs (nil for a game without one).
  def season(year, home_runs)
    season = Season.create!(year: year, term: "spring")
    home_runs.each_with_index do |count, i|
      game = Game.create!(season:, team0: @alpha, team1: @beta, played_on: Date.new(year, 4, 1) + i, game_number: i + 1,
        team0_score: 3, team1_score: 1, game_status: "試合終了")
      BattingLine.create!(game:, player: @player, university: @alpha, ab: 4, hits: 1, home_runs: count) if count
    end
    season
  end

  test "each season's home runs and per game, of the seasons with every box score and some home run" do
    counted = season(2001, [ 2, 1, 0, 1 ])
    season(2002, [ 3, nil ]) # a game without a box score
    no_record = season(2012, [ 0, 0 ]) # Scorebook's 2012 and 2013: no home run recorded

    assert_equal [ [ counted, 4, 4 ] ], SeasonHomeRuns.rows.map { |row| [ row.season, row.games, row.home_runs ] }
    assert_equal [ no_record ], SeasonHomeRuns.no_record.map(&:season)
    assert_equal 1, SeasonHomeRuns.without_box_scores
  end

  test "the fewest, the most, the mean and the population's standard deviation, with the seasons of each" do
    fewest = season(2001, [ 1, 1 ])
    most = season(2002, [ 3, 3 ])
    season(2003, [ 2, 2 ])

    summary = SeasonHomeRuns.summary(SeasonHomeRuns.rows, &:home_runs)

    assert_equal [ 2, 6, 4.0 ], [ summary.min, summary.max, summary.mean ]
    assert_in_delta Math.sqrt(8.0 / 3), summary.sd
    assert_equal [ [ fewest ], [ most ] ], [ summary.min_rows.map(&:season), summary.max_rows.map(&:season) ]
  end
end
