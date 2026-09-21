require "test_helper"

class GameTest < ActiveSupport::TestCase
  setup do
    @alpha = universities(:one)
    @beta = universities(:two)
    @season = seasons(:one)
  end

  def game(number, **attributes)
    Game.create!({ season: @season, team0: @alpha, team1: @beta, played_on: "2026-05-0#{number}", game_number: number }.merge(attributes))
  end

  test "with_stats_available needs a final score and a Scorebook id" do
    ready = game(1, game_status: "finished", team0_score: 3, team1_score: 2, scorebook_game_id: 2026050101)
    game(2, game_status: "finished", team0_score: nil, team1_score: nil, scorebook_game_id: 2026050201)
    game(3, game_status: "finished", team0_score: 1, team1_score: 0, scorebook_game_id: nil)
    game(4, game_status: "in_progress", team0_score: 2, team1_score: 1, scorebook_game_id: 2026050401) # a partial score

    assert_equal [ ready.id ], Game.with_stats_available.where(id: Game.where(game_number: 1..4)).pluck(:id)
  end

  test "needing_stats excludes games that already have batting lines" do
    imported = game(1, game_status: "finished", team0_score: 3, team1_score: 2, scorebook_game_id: 2026050101)
    pending = game(2, game_status: "finished", team0_score: 1, team1_score: 0, scorebook_game_id: 2026050201)
    player = Player.create!(scorebook_id: 20236010, university: @alpha, name: "落合 智哉", enter_year: 2023)
    BattingLine.create!(game: imported, player: player, university: @alpha)

    assert_equal [ pending.id ], Game.needing_stats.where(id: [ imported.id, pending.id ]).pluck(:id)
  end

  test "games count toward stats by default" do
    assert game(1).counted_in_stats
  end

  # ---- the five statuses

  test "a game is in one of five states, named as Scorebook and the league's site name them" do
    assert_equal({ "scheduled" => "試合前", "in_progress" => "試合中", "finished" => "試合終了", "cancelled" => "中止", "no_game" => "ノーゲーム" }, Game.game_statuses)
  end

  test "a new game is 試合前, and reads as its name while status_label is the Japanese one" do
    fresh = game(1)

    assert fresh.scheduled?
    assert_equal [ "scheduled", "試合前" ], [ fresh.game_status, fresh.status_label ]
    assert_equal "中止", game(2, game_status: "中止").status_label
    assert_equal "ノーゲーム", game(3, game_status: :no_game).status_label
  end

  test "the status is stored as the Japanese name" do
    stored = game(1, game_status: "finished", team0_score: 1, team1_score: 0)

    assert_equal "試合終了", Game.connection.select_value("SELECT game_status FROM games WHERE id = #{stored.id}")
    assert_equal [ stored.id ], Game.where(id: stored.id).where(game_status: "試合終了").pluck(:id)
    assert_equal [ stored.id ], Game.where(id: stored.id).finished.pluck(:id)
  end

  test "any other status is not valid" do
    assert_not Game.new(season: @season, team0: @alpha, team1: @beta, played_on: "2026-05-01", game_number: 1, game_status: "延期").valid?
    assert_not Game.new(season: @season, team0: @alpha, team1: @beta, played_on: "2026-05-01", game_number: 1, game_status: nil).valid?
  end

  test "not_held? is true for 中止 and ノーゲーム only, and held? for the rest" do
    { "試合前" => true, "試合中" => true, "試合終了" => true, "中止" => false, "ノーゲーム" => false }.each_with_index do |(status, held), index|
      assert_equal held, game(index + 1, game_status: status).held?, status
    end
    assert game(6, game_status: "中止").not_held?
    assert game(7, game_status: "ノーゲーム").not_held?
    assert game(8, game_status: "中止").cancelled?
    assert_not game(9, game_status: "ノーゲーム").cancelled?
  end

  test "held and not_held split the games" do
    a = game(1, game_status: "中止")
    b = game(2, game_status: "試合終了")
    c = game(3, game_status: "ノーゲーム")
    d = game(4, game_status: "試合前")
    scope = Game.where(id: [ a.id, b.id, c.id, d.id ])

    assert_equal [ a.id, c.id ].sort, scope.not_held.pluck(:id).sort
    assert_equal [ b.id, d.id ].sort, scope.held.pluck(:id).sort
  end

  test "status_for keeps a status of ours, else works it out from the score and the date" do
    yesterday, tomorrow = Date.current - 1, Date.current + 1

    assert_equal "中止", Game.status_for("中止", team0_score: nil, team1_score: nil, played_on: yesterday)
    assert_equal "試合終了", Game.status_for("終了", team0_score: 3, team1_score: 1, played_on: yesterday)
    assert_equal "試合前", Game.status_for(nil, team0_score: nil, team1_score: nil, played_on: tomorrow)
    assert_equal "試合前", Game.status_for("", team0_score: nil, team1_score: nil, played_on: Date.current)
    assert_equal "試合中", Game.status_for("5回裏", team0_score: nil, team1_score: nil, played_on: yesterday)
  end

  # ---- a game that wasn't held has no round number

  test "a cancelled game has no round number, whatever it is given" do
    cancelled = game(1, game_status: "中止")

    assert_nil cancelled.game_number
    assert_nil cancelled.reload.game_number
    cancelled.update!(game_status: "finished", game_number: 2, team0_score: 1, team1_score: 0)
    assert_equal 2, cancelled.reload.game_number
    cancelled.update!(game_status: "中止")
    assert_nil cancelled.reload.game_number
  end

  test "a game called off (ノーゲーム) has no round number either" do
    assert_nil game(1, game_status: "ノーゲーム").game_number
  end

  test "a game held needs its round number" do
    assert_not Game.new(season: @season, team0: @alpha, team1: @beta, played_on: "2026-05-01", game_number: nil, game_status: "試合前").valid?
    assert Game.new(season: @season, team0: @alpha, team1: @beta, played_on: "2026-05-01", game_number: nil, game_status: "中止").valid?
  end

  # ---- record_cancellation

  test "record_cancellation marks the game between the teams on that date, either way round, taking away its score and round" do
    scheduled = game(1, game_status: "試合前")
    voided = game(2, game_status: "試合終了", team0_score: 2, team1_score: 2)

    result = Game.record_cancellation(season: @season, teams: [ @beta, @alpha ], played_on: Date.new(2026, 5, 1))
    Game.record_cancellation(season: @season, teams: [ @alpha, @beta ], played_on: Date.new(2026, 5, 2), status: "ノーゲーム")

    assert_equal scheduled, result
    assert_equal [ "cancelled", nil, nil, nil ], [ scheduled.reload.game_status, scheduled.game_number, scheduled.team0_score, scheduled.team1_score ]
    assert_equal [ "no_game", nil, nil, nil ], [ voided.reload.game_status, voided.game_number, voided.team0_score, voided.team1_score ]
  end

  test "record_cancellation finds the game by its Scorebook id first" do
    moved = game(1, game_status: "試合前", scorebook_game_id: 2026050101)

    assert_equal moved, Game.record_cancellation(season: @season, teams: [ @alpha, @beta ], played_on: Date.new(2026, 6, 1), scorebook_game_id: 2026050101)
    assert moved.reload.cancelled?
  end

  test "record_cancellation adds the game when we do not have it: teams[0] on top, no round, with what else it is given" do
    count = Game.count

    added = Game.record_cancellation(
      season: @season, teams: [ @beta, @alpha ], played_on: Date.new(2026, 5, 9), scorebook_game_id: 2026050901, status: "中止",
      attributes: { game_order: 2, counted_in_stats: false }
    )

    assert_equal count + 1, Game.count
    assert added.persisted?
    assert_equal [ @beta, @alpha, "cancelled", nil, 2026050901, 2, false ],
      [ added.team0, added.team1, added.game_status, added.game_number, added.scorebook_game_id, added.game_order, added.counted_in_stats ]
  end

  test "record_cancellation does not add a second game for the one it already has" do
    game(1, game_status: "試合前")
    count = Game.count

    2.times { Game.record_cancellation(season: @season, teams: [ @alpha, @beta ], played_on: Date.new(2026, 5, 1)) }

    assert_equal count, Game.count
  end

  test "record_cancellation leaves other games and seasons alone" do
    other = game(1, game_status: "試合前")
    Game.record_cancellation(season: @season, teams: [ @alpha, @beta ], played_on: Date.new(2026, 5, 9))
    Game.record_cancellation(season: seasons(:two), teams: [ @alpha, @beta ], played_on: Date.new(2026, 5, 1))

    assert_equal "scheduled", other.reload.game_status
    assert_equal 1, other.game_number
  end

  test "record_cancellation with unless_finished leaves a finished game alone" do
    finished = game(1, game_status: "試合終了", team0_score: 3, team1_score: 1)
    pending = game(2, game_status: "試合前")

    assert_nil Game.record_cancellation(season: @season, teams: [ @alpha, @beta ], played_on: Date.new(2026, 5, 1), unless_finished: true)
    assert_equal pending, Game.record_cancellation(season: @season, teams: [ @alpha, @beta ], played_on: Date.new(2026, 5, 2), unless_finished: true)
    assert_equal [ "finished", 3, 1 ], [ finished.reload.game_status, finished.team0_score, finished.game_number ]
    assert pending.reload.cancelled?
  end

  # ---- decided

  test "a game is decided when it is over and has a score" do
    assert game(1, game_status: "finished", team0_score: 3, team1_score: 1).decided?
    assert_not game(2, game_status: "in_progress", team0_score: 3, team1_score: 1).decided? # a score, but not a final one
    assert_not game(3, game_status: "finished").decided?
    assert_not game(4, game_status: "scheduled").decided?
    assert_not game(5, game_status: "cancelled").decided?
  end
end
