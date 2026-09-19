require "test_helper"

class PlayerStatsTest < ActiveSupport::TestCase
  setup do
    @alpha = universities(:one)
    @beta = universities(:two)
    @spring = seasons(:one)
    @autumn = seasons(:two)
    @player = Player.create!(scorebook_id: 20236010, university: @alpha, name: "落合 智哉", enter_year: 2023)
  end

  def game(season, played_on, game_number, counted: true)
    Game.create!(season: season, team0: @alpha, team1: @beta, played_on: played_on, game_number: game_number, counted_in_stats: counted)
  end

  def bat(game, **stats)
    BattingLine.create!({ game: game, player: @player, university: @alpha }.merge(stats))
  end

  def pitch(game, **stats)
    PitchingLine.create!({ game: game, player: @player, university: @alpha }.merge(stats))
  end

  test "has no stats until there are lines" do
    stats = PlayerStats.new(@player)

    assert_not stats.batting?
    assert_not stats.pitching?
    assert_empty stats.batting_seasons
  end

  test "season rows are oldest first with spring before autumn, each summing its own games" do
    bat(game(@autumn, "2026-09-20", 1), ab: 4, hits: 2)
    bat(game(@spring, "2026-05-02", 1), ab: 3, hits: 1)
    bat(game(@spring, "2026-05-03", 2), ab: 4, hits: 3, home_runs: 1)

    rows = PlayerStats.new(@player).batting_seasons

    assert_equal [ @spring, @autumn ], rows.map(&:season)
    assert_equal [ 2, 7, 4, 1 ], [ rows[0].totals.games, rows[0].totals.ab, rows[0].totals.hits, rows[0].totals.home_runs ]
    assert_equal [ 1, 4, 2 ], [ rows[1].totals.games, rows[1].totals.ab, rows[1].totals.hits ]
  end

  test "the career total sums every counted game" do
    bat(game(@spring, "2026-05-02", 1), ab: 3, hits: 1)
    bat(game(@autumn, "2026-09-20", 1), ab: 5, hits: 2)

    total = PlayerStats.new(@player).batting_total

    assert_equal [ 2, 8, 3 ], [ total.games, total.ab, total.hits ]
    assert_in_delta 0.375, total.average, 0.0001
  end

  test "games flagged as not counted are listed but left out of seasons and the career total" do
    bat(game(@spring, "2026-05-02", 1), ab: 3, hits: 1)
    playoff = game(@spring, "2026-06-04", 5, counted: false)
    bat(playoff, ab: 4, hits: 4)

    stats = PlayerStats.new(@player)

    assert_equal [ playoff.id, stats.batting_lines.last.game_id ], stats.batting_lines.map(&:game_id)
    assert_equal [ 1, 3, 1 ], [ stats.batting_seasons.first.totals.games, stats.batting_seasons.first.totals.ab, stats.batting_seasons.first.totals.hits ]
    assert_equal 3, stats.batting_total.ab
  end

  test "a season with only uncounted games has no season row" do
    bat(game(@spring, "2026-06-04", 5, counted: false), ab: 4, hits: 4)

    assert_empty PlayerStats.new(@player).batting_seasons
    assert_equal 0, PlayerStats.new(@player).batting_total.games
  end

  test "per-game lines are most recent first" do
    bat(game(@spring, "2026-05-02", 1))
    bat(game(@autumn, "2026-09-20", 1))
    bat(game(@spring, "2026-05-03", 2))

    assert_equal %w[2026-09-20 2026-05-03 2026-05-02], PlayerStats.new(@player).batting_lines.map { |line| line.game.played_on.to_s }
  end

  test "pitching stats are summed in outs, with an earned run average" do
    pitch(game(@spring, "2026-05-02", 1), outs: 27, earned_runs: 1, wins: 1, started: 1, complete_game: 1)
    pitch(game(@spring, "2026-05-09", 2), outs: 10, earned_runs: 3, losses: 1)

    stats = PlayerStats.new(@player)

    assert stats.pitching?
    assert_equal [ 2, 37, 4, 1, 1 ], [ stats.pitching_total.games, stats.pitching_total.outs, stats.pitching_total.earned_runs, stats.pitching_total.wins, stats.pitching_total.losses ]
    assert_in_delta 2.919, stats.pitching_total.era, 0.001
    assert_equal 1, stats.pitching_seasons.size
  end
end
