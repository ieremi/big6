require "test_helper"

class ScorebookSyncTest < ActiveSupport::TestCase
  setup do
    @hosei = University.create!(name: "Hosei University", short_name: "法大", slug: "hosei", position: 4)
    @rikkio = University.create!(name: "Rikkio University", short_name: "立大", slug: "rikkio", position: 6)
    @season = Season.create!(year: 2026, term: "autumn")
  end

  # A Scorebook entry for hosei (top, 4) at rikkio (bottom, 6).
  def entry(id, day, round, status, counted: true, top_runs: nil, bottom_runs: nil, order: 1)
    {
      "id" => id, "gameDay" => "#{day}T00:00:00.000Z", "topTeamId" => 4, "bottomTeamId" => 6, "round" => round,
      "gameStatus" => status, "runsTotalTop" => top_runs, "runsTotalBottom" => bottom_runs, "gameOrder" => order,
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

  # [date, round, status] of each game, by date.
  def shape
    games.map { |game| [ game.played_on.to_s, game.game_number, game.status_label ] }
  end

  # ---- games that weren't held

  test "a cancelled entry marks the game we have for it, taking away its score and round" do
    scheduled = create_game("2026-09-20", 2, game_status: "試合前", scorebook_game_id: 2026092001)
    bogus = create_game("2026-09-21", 3, game_status: "試合終了", team0_score: 0, team1_score: 0)

    import(entry(2026092001, "2026-09-20", "2回戦", "中止"), entry(2026092101, "2026-09-21", "3回戦", "ノーゲーム"))

    assert_equal [ "cancelled", nil, nil, nil ], [ scheduled.reload.game_status, scheduled.game_number, scheduled.team0_score, scheduled.team1_score ]
    assert_equal [ "no_game", nil, nil, nil ], [ bogus.reload.game_status, bogus.game_number, bogus.team0_score, bogus.team1_score ]
    assert_equal 2, Game.where(season: @season).count
  end

  test "a cancelled entry for a game we never had is added, with no round" do
    import(entry(2026092001, "2026-09-20", "2回戦", "中止", order: 2, counted: false))

    added = games.sole
    assert_equal [ @hosei, @rikkio, "cancelled", nil, 2026092001, 2, false ], [ added.team0, added.team1, added.game_status, added.game_number, added.scorebook_game_id, added.game_order, added.counted_in_stats ]
  end

  test "two cancelled days are both recorded, whether or not we had a row for one of them" do
    create_game("2026-09-20", 2, game_status: "試合前")

    import(entry(2026092001, "2026-09-20", "2回戦", "中止"), entry(2026092101, "2026-09-21", "1回戦", "中止"))

    assert_equal [ [ "2026-09-20", nil, "中止" ], [ "2026-09-21", nil, "中止" ] ], shape
  end

  test "importing again does not add the cancelled game twice" do
    entries = [ entry(2026092001, "2026-09-20", "2回戦", "中止") ]

    2.times { import(*entries) }

    assert_equal 1, Game.where(season: @season).count
  end

  test "a cancelled entry is found by its Scorebook id even when the date differs" do
    game = create_game("2026-09-20", 2, game_status: "試合前", scorebook_game_id: 2026092001)

    import(entry(2026092001, "2026-09-21", "2回戦", "中止"))

    assert_equal [ game.id, "cancelled" ], [ Game.where(season: @season).sole.id, game.reload.game_status ]
  end

  test "the replay of a cancelled game is a game of its own, and takes the round" do
    import(
      entry(2026091902, "2026-09-19", "1回戦", "試合終了", top_runs: "5", bottom_runs: "12"),
      entry(2026092001, "2026-09-20", "2回戦", "中止"),
      entry(2026092201, "2026-09-22", "2回戦", "試合前")
    )

    assert_equal [ [ "2026-09-19", 1, "試合終了" ], [ "2026-09-20", nil, "中止" ], [ "2026-09-22", 2, "試合前" ] ], shape
  end

  test "a replay that Scorebook labels with a round already played gets the next number" do
    import(
      entry(2026091902, "2026-09-19", "1回戦", "試合終了", top_runs: "5", bottom_runs: "12"),
      entry(2026092001, "2026-09-20", "2回戦", "中止"),
      entry(2026092101, "2026-09-21", "1回戦", "中止"),
      entry(2026092201, "2026-09-22", "1回戦", "試合前")
    )

    assert_equal [ [ "2026-09-19", 1, "試合終了" ], [ "2026-09-20", nil, "中止" ], [ "2026-09-21", nil, "中止" ], [ "2026-09-22", 2, "試合前" ] ], shape
  end

  test "a replay keeps its label when nothing was played under it" do
    import(
      entry(2025051701, "2026-05-17", "1回戦", "中止"),
      entry(2025051802, "2026-05-18", "1回戦", "試合終了", top_runs: "0", bottom_runs: "3"),
      entry(2025051901, "2026-05-19", "2回戦", "試合終了", top_runs: "0", bottom_runs: "1")
    )

    assert_equal [ nil, 1, 2 ], games.map(&:game_number)
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

    assert_equal [ [ "2026-05-15", 1 ], [ "2026-05-16", nil ], [ "2026-06-03", nil ], [ "2026-06-04", 1 ] ], games.map { |game| [ game.played_on.to_s, game.game_number ] }
  end

  test "Scorebook still saying a game hasn't started does not undo a cancellation recorded from the league's site" do
    game = create_game("2026-09-20", nil, game_status: "中止")

    import(entry(2026092001, "2026-09-20", "2回戦", "試合前"))

    assert_equal [ "cancelled", nil, 2026092001 ], [ game.reload.game_status, game.game_number, game.scorebook_game_id ]
  end

  test "but a game Scorebook reports played is no longer cancelled, and has its round again" do
    game = create_game("2026-09-20", nil, game_status: "中止")

    import(entry(2026092001, "2026-09-20", "2回戦", "試合終了", top_runs: "3", bottom_runs: "1"))

    assert_equal [ "finished", 2, 3, 1 ], [ game.reload.game_status, game.game_number, game.team0_score, game.team1_score ]
  end

  test "entries are numbered in date order however Scorebook lists them" do
    import(
      entry(3, "2026-09-22", "1回戦", "試合前"),
      entry(1, "2026-09-19", "1回戦", "試合終了", top_runs: "5", bottom_runs: "12"),
      entry(2, "2026-09-20", "2回戦", "中止")
    )

    assert_equal [ [ "2026-09-19", 1 ], [ "2026-09-20", nil ], [ "2026-09-22", 2 ] ], games.map { |game| [ game.played_on.to_s, game.game_number ] }
  end

  # ---- the status of a game that was held

  test "the status is the one Scorebook reports, or worked out when it reports something else" do
    import(
      entry(1, "2026-05-01", "1回戦", "試合終了", top_runs: "5", bottom_runs: "12"),
      entry(2, "#{Date.current + 3}", "2回戦", "試合前"),
      entry(3, "#{Date.current - 1}", "3回戦", "5回裏")
    )

    assert_equal [ "試合終了", "試合中", "試合前" ], games.map(&:status_label)  # by date: 5/1, yesterday, in three days
  end

  # ---- record_stored_cancellations

  def record_stored(*entries)
    @season.update!(scorebook_games: entries)
    stub_method(Net::HTTP, :get_response, ->(*) { raise "fetched from the network" }) do
      ScorebookSync.new(@season).record_stored_cancellations
    end
  end

  test "stored cancellations mark the games left over from the old importer, fetching nothing" do
    # the cancelled entry has hosei on top, the replay the other way round: not a duplicate as far as the old cleanup could tell
    leftover = Game.create!(season: @season, team0: @hosei, team1: @rikkio, played_on: "2026-09-20", game_number: 1, scorebook_game_id: 2026092001)
    replay = Game.create!(season: @season, team0: @rikkio, team1: @hosei, played_on: "2026-09-21", game_number: 1, game_status: "試合終了", team0_score: 4, team1_score: 2, scorebook_game_id: 2026092101)

    marked = record_stored(
      entry(2026092001, "2026-09-20", "1回戦", "中止"),
      entry(2026092101, "2026-09-21", "1回戦", "試合終了", top_runs: "4", bottom_runs: "2")
    )

    assert_equal [ leftover ], marked
    assert_equal [ "cancelled", nil ], [ leftover.reload.game_status, leftover.game_number ]
    assert_equal [ "finished", 4, 1 ], [ replay.reload.game_status, replay.team0_score, replay.game_number ]
  end

  test "stored cancellations find a game with no Scorebook id by its teams and date, in either order" do
    leftover = Game.create!(season: @season, team0: @rikkio, team1: @hosei, played_on: "2026-09-20", game_number: 1)

    assert_equal [ leftover ], record_stored(entry(2026092001, "2026-09-20", "1回戦", "中止"))
  end

  test "stored cancellations clear the 0-0 that the old importer made of a cancelled game's empty score" do
    leftover = Game.create!(season: @season, team0: @hosei, team1: @rikkio, played_on: "2026-09-20", game_number: 1, team0_score: 0, team1_score: 0)

    record_stored(entry(2026092001, "2026-09-20", "1回戦", "中止"))

    assert_equal [ "cancelled", nil, nil ], [ leftover.reload.game_status, leftover.team0_score, leftover.team1_score ]
  end

  test "stored cancellations leave alone a game that Scorebook has as finished, whatever an older report says" do
    played = Game.create!(season: @season, team0: @hosei, team1: @rikkio, played_on: "2026-09-20", game_number: 1, game_status: "試合終了", team0_score: 3, team1_score: 1)

    assert_empty record_stored(entry(2026092001, "2026-09-20", "1回戦", "中止"))
    assert_equal [ "finished", 3 ], [ played.reload.game_status, played.team0_score ]
  end

  test "stored cancellations add the games we did not have, once" do
    Game.create!(season: @season, team0: @hosei, team1: @rikkio, played_on: "2026-09-20", game_number: 2)
    entries = [ entry(2026092001, "2026-09-20", "2回戦", "中止"), entry(2026092101, "2026-09-21", "1回戦", "ノーゲーム") ]

    assert_equal 2, record_stored(*entries).size
    assert_empty record_stored(*entries) # nothing new the second time
    assert_equal [ [ "2026-09-20", nil, "中止" ], [ "2026-09-21", nil, "ノーゲーム" ] ], shape
  end

  test "stored cancellations are nothing for a season with no stored data" do
    assert_empty ScorebookSync.new(@season).record_stored_cancellations
  end
end
