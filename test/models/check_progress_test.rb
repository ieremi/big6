require "test_helper"

class CheckProgressTest < ActiveSupport::TestCase
  setup do
    @game = games(:one)
    @players = (1..3).map do |i|
      Player.create!(scorebook_id: 70_000_000 + i, university: universities(:one), name: "選手#{i}", enter_year: 2023).tap do |player|
        BattingLine.create!(game: @game, player: player, university: player.university, pa: 4)
      end
    end
  end

  def check(player, at)
    ScorebookStatsPlayerCheck.create!(player: player, checked_at: at)
  end

  test "counts the players with batting lines checked at least once, and the nights left at 480 a night" do
    check(@players[0], 2.days.ago)
    check(@players[1], 1.hour.ago)
    check(Player.create!(scorebook_id: 70_000_009, university: universities(:one), name: "成績なし", enter_year: 2023), 1.hour.ago)

    progress = CheckProgress.new

    assert_equal 480, CheckProgress::PLAYERS_PER_NIGHT
    assert_equal [ 3, 2, 1 ], [ progress.players_total, progress.players_checked, progress.players_remaining ]
    assert_equal [ 1, 1 ], [ progress.nights_remaining, progress.nights_per_round ]
    assert_equal 1, progress.checked_in_last_day
    assert_in_delta 2.days.ago, progress.oldest_check_at, 5
  end

  test "once everyone has been checked, no nights are left" do
    @players.each { |player| check(player, 1.day.ago) }

    assert_equal 0, CheckProgress.new.nights_remaining
  end

  # The fixtures have alpha v beta on 2026-08-10 in both seasons: a university
  # with two games on one day, found once for each side.
  test "counts the games data check's findings per kind, and how many of them are reviewed" do
    findings = GameDataCheck.new.findings
    GameCheckReview.create!(key: findings.find { |finding| finding.kind == "same_day" }.key)

    progress = CheckProgress.new
    same_day = progress.game_check_counts.find { |kind, _, _| kind == "same_day" }

    assert_equal [ "same_day", findings.count { |finding| finding.kind == "same_day" }, 1 ], same_day
    assert_equal findings.size, progress.game_findings_total
    assert_equal 1, progress.game_findings_reviewed
  end
end
