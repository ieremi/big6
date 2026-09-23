require "test_helper"

class CheckScorebookStatsJobTest < ActiveJob::TestCase
  setup do
    @alpha = universities(:one)
    @players = (1..3).map do |n|
      player = Player.create!(scorebook_id: 20160000 + n, university: @alpha, name: "選手 #{n}", enter_year: 2016)
      BattingLine.create!(game: games(:one), player: player, university: @alpha, pa: 4, ab: 4)
      player
    end
    @without_lines = Player.create!(scorebook_id: 20169999, university: @alpha, name: "控え 選手", enter_year: 2016)
  end

  def checked_ids
    ids = []
    stub_method(ScorebookMemberStats, :fetch, ->(id) { ids << id; [] }) { yield }
    ids
  end

  test "checks the players never checked first, then those checked longest ago, and only those with batting lines" do
    ScorebookStatsPlayerCheck.create!(player: @players[0], checked_at: 1.day.ago)
    ScorebookStatsPlayerCheck.create!(player: @players[1], checked_at: 3.days.ago)

    ids = checked_ids { CheckScorebookStatsJob.perform_now(batch_size: 2, sleep_seconds: 0) }

    assert_equal [ @players[2], @players[1] ].map(&:scorebook_id), ids
    assert_nil @without_lines.reload.scorebook_stats_player_check
  end

  test "every player is checked in turn over several runs" do
    ids = checked_ids { 3.times { CheckScorebookStatsJob.perform_now(batch_size: 2, sleep_seconds: 0) } }

    assert_equal @players.map(&:scorebook_id).sort, ids.first(3).sort
    assert_equal 3, ScorebookStatsPlayerCheck.count
  end

  test "one player's failure doesn't stop the others" do
    failing = ->(id) { raise "boom" if id == @players[0].scorebook_id; [] }

    stub_method(ScorebookMemberStats, :fetch, failing) { CheckScorebookStatsJob.perform_now(batch_size: 3, sleep_seconds: 0) }

    assert_equal @players[1..].map(&:id).sort, ScorebookStatsPlayerCheck.pluck(:player_id).sort
  end
end
