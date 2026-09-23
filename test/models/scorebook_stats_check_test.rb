require "test_helper"

class ScorebookStatsCheckTest < ActiveSupport::TestCase
  setup do
    @alpha = universities(:one)
    @beta = universities(:two)
    @player = Player.create!(scorebook_id: 20164001, university: @alpha, name: "安本 竜二", enter_year: 2016)
    @first = create_game(2019041301, "2019-04-13", 1)
    @second = create_game(2019041401, "2019-04-14", 2)
  end

  def create_game(scorebook_game_id, day, number)
    Game.create!(season: seasons(:one), team0: @alpha, team1: @beta, played_on: day, game_number: number,
      team0_score: 3, team1_score: 1, game_status: "試合終了", scorebook_game_id: scorebook_game_id)
  end

  def bat(game, **values)
    BattingLine.create!({ game: game, player: @player, university: @alpha, pa: 4, ab: 4, hits: 1 }.merge(values))
  end

  def line(game_id, day, **values)
    ScorebookMemberStats::Line.new(scorebook_game_id: game_id, played_on: Date.parse(day),
      values: { pa: 4, ab: 4, hits: 1, runs: 0 }.merge(values))
  end

  def check(lines, **options)
    ScorebookStatsCheck.new(fetcher: ->(_id) { lines }, **options)
  end

  test "lines that agree are no difference" do
    bat(@first)

    assert_equal [], check([ line(2019041301, "2019-04-13") ]).call(@player)
  end

  test "a value that differs is a difference of that column, with both values" do
    bat(@first, hits: 3)

    differences = check([ line(2019041301, "2019-04-13", hits: 2) ]).call(@player)

    assert_equal [ "value 20164001 2019041301 hits" ], differences.map(&:key)
    assert_equal [ 2, 3 ], [ differences.first.scorebook, differences.first.ours ]
    assert_match "安本 竜二 2019-04-13 hits: Scorebook 2 / ours 3", differences.first.to_s
  end

  test "a game only Scorebook has is missing, and one only we have is extra" do
    bat(@second)
    teammate = Player.create!(scorebook_id: 20164002, university: @alpha, name: "柳町 達", enter_year: 2016)
    BattingLine.create!(game: @first, player: teammate, university: @alpha, pa: 4, ab: 4) # the game's box score is in, without him

    differences = check([ line(2019041301, "2019-04-13") ]).call(@player)

    assert_equal [ "missing 20164001 2019041301", "extra 20164001 2019041401" ], differences.map(&:key)
  end

  test "a game we have no one's lines for is no_stats, not missing" do
    bat(@first)

    differences = check([ line(2019041301, "2019-04-13"), line(2019041401, "2019-04-14") ]).call(@player)

    assert_equal [ "no_stats 20164001 2019041401" ], differences.map(&:key)
  end

  test "a line Scorebook files under another game of the same day is matched by its date" do
    bat(@first, hits: 2)

    differences = check([ line(2019041302, "2019-04-13", hits: 2) ]).call(@player)

    assert_equal [], differences
  end

  test "a game Scorebook lists twice is a duplicate, and its values aren't compared" do
    bat(@first)

    differences = check([ line(2019041301, "2019-04-13"), line(2019041301, "2019-04-13", hits: 3) ]).call(@player)

    assert_equal [ "duplicate 20164001 2019041301" ], differences.map(&:key)
  end

  test "a value Scorebook didn't record is no difference, but counted when ours is 0" do
    bat(@first, runs: 0, stolen_bases: 1)

    checker = check([ line(2019041301, "2019-04-13", runs: nil, stolen_bases: nil) ])

    assert_equal [], checker.call(@player)
    assert_equal({ runs: 1 }, checker.unknown_as_zero)
  end

  test "a page that can't be read is nil, not no differences" do
    assert_nil check(nil).call(@player)
  end
end
