require "test_helper"

class ScorebookSyncTest < ActiveSupport::TestCase
  setup do
    @hosei = University.create!(name: "Hosei University", short_name: "法大", slug: "hosei", position: 4)
    @rikkio = University.create!(name: "Rikkio University", short_name: "立大", slug: "rikkio", position: 6)
    @season = Season.create!(year: 2026, term: "autumn")
  end

  # A Scorebook entry for hosei (top, 4) at rikkio (bottom, 6).
  def entry(id, day, round, status, counted: true, top_runs: nil, bottom_runs: nil)
    {
      "id" => id, "gameDay" => "#{day}T00:00:00.000Z", "topTeamId" => 4, "bottomTeamId" => 6, "round" => round,
      "gameStatus" => status, "runsTotalTop" => top_runs, "runsTotalBottom" => bottom_runs, "gameOrder" => 1,
      "isCounted" => counted, "gameTimeNet" => nil, "attendance" => nil
    }
  end

  def import(*entries)
    ScorebookSync.new(@season).send(:import_games, entries)
  end

  def create_game(day, number, **attributes)
    Game.create!({ season: @season, team0: @hosei, team1: @rikkio, played_on: day, game_number: number }.merge(attributes))
  end

  def games
    Game.where(season: @season).order(:played_on).to_a
  end

  test "a cancelled entry marks the game we have for it as cancelled, and clears its score" do
    scheduled = create_game("2026-09-20", 2, game_status: "試合前", scorebook_game_id: 2026092001)
    bogus = create_game("2026-09-21", 3, game_status: "試合終了", team0_score: 0, team1_score: 0)

    import(entry(2026092001, "2026-09-20", "2回戦", "中止"), entry(2026092101, "2026-09-21", "3回戦", "ノーゲーム"))

    assert_equal [ "中止", nil, nil ], [ scheduled.reload.game_status, scheduled.team0_score, scheduled.team1_score ]
    assert_equal [ "ノーゲーム", nil, nil ], [ bogus.reload.game_status, bogus.team0_score, bogus.team1_score ]
    assert_equal 2, Game.where(season: @season).count
  end

  test "a cancelled entry for a game we never had is not added" do
    import(entry(2026092001, "2026-09-20", "2回戦", "中止"))

    assert_equal 0, Game.where(season: @season).count
  end

  test "a cancelled entry is found by its Scorebook id even when the date differs" do
    game = create_game("2026-09-20", 2, game_status: "試合前", scorebook_game_id: 2026092001)

    import(entry(2026092001, "2026-09-21", "2回戦", "中止"))

    assert_equal "中止", game.reload.game_status
  end

  test "the replay of a cancelled game is a game of its own" do
    create_game("2026-09-19", 1, game_status: "試合終了", team0_score: 5, team1_score: 12)
    create_game("2026-09-20", 2, game_status: "試合前", scorebook_game_id: 2026092001)

    import(
      entry(2026091902, "2026-09-19", "1回戦", "試合終了", top_runs: "5", bottom_runs: "12"),
      entry(2026092001, "2026-09-20", "2回戦", "中止"),
      entry(2026092201, "2026-09-22", "2回戦", "試合前")
    )

    assert_equal [ [ "2026-09-19", 1, "試合終了" ], [ "2026-09-20", 2, "中止" ], [ "2026-09-22", 2, "試合前" ] ],
      games.map { |game| [ game.played_on.to_s, game.game_number, game.game_status ] }
  end

  test "a replay that Scorebook labels with a round already played gets the next number" do
    import(
      entry(2026091902, "2026-09-19", "1回戦", "試合終了", top_runs: "5", bottom_runs: "12"),
      entry(2026092001, "2026-09-20", "2回戦", "中止"),
      entry(2026092101, "2026-09-21", "1回戦", "中止"),
      entry(2026092201, "2026-09-22", "1回戦", "試合前")
    )

    assert_equal [ [ "2026-09-19", 1 ], [ "2026-09-22", 2 ] ], games.map { |game| [ game.played_on.to_s, game.game_number ] }
  end

  test "a replay keeps its label when nothing was played under it" do
    import(
      entry(2025051701, "2026-05-17", "1回戦", "中止"),
      entry(2025051802, "2026-05-18", "1回戦", "試合終了", top_runs: "0", bottom_runs: "3"),
      entry(2025051901, "2026-05-19", "2回戦", "試合終了", top_runs: "0", bottom_runs: "1")
    )

    assert_equal [ 1, 2 ], games.map(&:game_number)
  end

  test "a repeated label is left alone when the pair had no game cancelled" do
    import(
      entry(1, "2026-05-15", "1回戦", "試合終了", top_runs: "1", bottom_runs: "0"),
      entry(2, "2026-05-16", "1回戦", "試合終了", top_runs: "2", bottom_runs: "2")
    )

    assert_equal [ 1, 1 ], games.map(&:game_number)
  end

  test "a playoff is a series of its own, whatever was cancelled in the season" do
    import(
      entry(1, "2026-05-15", "1回戦", "試合終了", top_runs: "1", bottom_runs: "0"),
      entry(2, "2026-05-16", "2回戦", "中止"),
      entry(3, "2026-06-03", "1回戦", "中止", counted: false),
      entry(4, "2026-06-04", "1回戦", "試合終了", counted: false, top_runs: "5", bottom_runs: "6")
    )

    assert_equal [ [ "2026-05-15", 1 ], [ "2026-06-04", 1 ] ], games.map { |game| [ game.played_on.to_s, game.game_number ] }
  end

  test "Scorebook still saying a game hasn't started does not undo a cancellation recorded from the league's site" do
    game = create_game("2026-09-20", 2, game_status: "中止")

    import(entry(2026092001, "2026-09-20", "2回戦", "試合前"))

    assert_equal "中止", game.reload.game_status
    assert_equal 2026092001, game.scorebook_game_id
  end

  test "but a game Scorebook reports played or under way is no longer cancelled" do
    game = create_game("2026-09-20", 2, game_status: "中止")

    import(entry(2026092001, "2026-09-20", "2回戦", "試合終了", top_runs: "3", bottom_runs: "1"))

    assert_equal [ "試合終了", 3, 1 ], [ game.reload.game_status, game.team0_score, game.team1_score ]
  end

  test "entries are numbered in date order however Scorebook lists them" do
    import(
      entry(3, "2026-09-22", "1回戦", "試合前"),
      entry(1, "2026-09-19", "1回戦", "試合終了", top_runs: "5", bottom_runs: "12"),
      entry(2, "2026-09-20", "2回戦", "中止")
    )

    assert_equal [ [ "2026-09-19", 1 ], [ "2026-09-22", 2 ] ], games.map { |game| [ game.played_on.to_s, game.game_number ] }
  end
end
