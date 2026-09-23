require "test_helper"

class ScorebookStatsPlayerCheckTest < ActiveSupport::TestCase
  setup do
    @alpha = universities(:one)
    @player = Player.create!(scorebook_id: 20164001, university: @alpha, name: "安本 竜二", enter_year: 2016)
    @game = Game.create!(season: seasons(:one), team0: @alpha, team1: universities(:two), played_on: "2019-04-13", game_number: 1,
      team0_score: 3, team1_score: 1, game_status: "試合終了", scorebook_game_id: 2019041301)
    BattingLine.create!(game: @game, player: @player, university: @alpha, pa: 4, ab: 4, hits: 1)
  end

  def line(**values)
    ScorebookMemberStats::Line.new(scorebook_game_id: 2019041301, played_on: Date.new(2019, 4, 13),
      values: { pa: 4, ab: 4, hits: 1, runs: nil }.merge(values))
  end

  def run_check(lines, now: Time.current)
    ScorebookStatsPlayerCheck.run(@player, fetcher: ->(_id) { lines }, now: now)
  end

  test "records the check and the differences it found" do
    run_check([ line(hits: 2) ])

    check = @player.reload.scorebook_stats_player_check
    assert check.readable
    assert_equal({ "runs" => 1 }, check.unknown_as_zero)
    difference = @player.scorebook_stats_differences.sole
    assert_equal [ "value", 2019041301, "hits", 2, 1, false ], [ difference.kind, difference.scorebook_game_id, difference.field, difference.scorebook_value, difference.our_value, difference.known ]
  end

  test "a difference found again keeps its row, so when it was first found and whether it is known" do
    first_seen = 2.days.ago
    run_check([ line(hits: 2) ], now: first_seen)
    ScorebookStatsDifference.update_all(known: true)

    run_check([ line(hits: 3) ])

    difference = @player.scorebook_stats_differences.sole
    assert difference.known
    assert_equal 3, difference.scorebook_value
    assert_in_delta first_seen, difference.created_at, 1
  end

  test "a difference not found any more goes" do
    run_check([ line(hits: 2) ])
    run_check([ line ])

    assert_empty @player.scorebook_stats_differences
    assert @player.scorebook_stats_player_check.checked_at > 1.minute.ago
  end

  test "a page that can't be read is recorded, and leaves the differences as they were" do
    run_check([ line(hits: 2) ])
    run_check(nil)

    assert_not @player.reload.scorebook_stats_player_check.readable
    assert_equal 1, @player.scorebook_stats_differences.count
  end

  test "a game we have no box score for isn't counted as a difference" do
    run_check([ line, ScorebookMemberStats::Line.new(scorebook_game_id: 2019041401, played_on: Date.new(2019, 4, 14), values: { pa: 4 }) ])
    Game.create!(season: seasons(:one), team0: @alpha, team1: universities(:two), played_on: "2019-04-14", game_number: 2, scorebook_game_id: 2019041401)
    run_check([ line, ScorebookMemberStats::Line.new(scorebook_game_id: 2019041401, played_on: Date.new(2019, 4, 14), values: { pa: 4 }) ])

    assert_equal [ "no_stats" ], ScorebookStatsDifference.pluck(:kind)
    assert_empty ScorebookStatsDifference.unknown
  end
end
