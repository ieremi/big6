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
    ready = game(1, team0_score: 3, team1_score: 2, scorebook_game_id: 2026050101)
    game(2, team0_score: nil, team1_score: nil, scorebook_game_id: 2026050201)
    game(3, team0_score: 1, team1_score: 0, scorebook_game_id: nil)

    assert_equal [ ready.id ], Game.with_stats_available.where(id: Game.where(game_number: 1..3)).pluck(:id)
  end

  test "needing_stats excludes games that already have batting lines" do
    imported = game(1, team0_score: 3, team1_score: 2, scorebook_game_id: 2026050101)
    pending = game(2, team0_score: 1, team1_score: 0, scorebook_game_id: 2026050201)
    player = Player.create!(scorebook_id: 20236010, university: @alpha, name: "落合 智哉", enter_year: 2023)
    BattingLine.create!(game: imported, player: player, university: @alpha)

    assert_equal [ pending.id ], Game.needing_stats.where(id: [ imported.id, pending.id ]).pluck(:id)
  end

  test "games count toward stats by default" do
    assert game(1).counted_in_stats
  end

  # ---- cancelled games

  test "cancelled? is true for 中止 and ノーゲーム only" do
    assert game(1, game_status: "中止").cancelled?
    assert game(2, game_status: "ノーゲーム").cancelled?
    assert_not game(3, game_status: "試合前").cancelled?
    assert_not game(4, game_status: "試合終了").cancelled?
    assert_not game(5, game_status: nil).cancelled?
  end

  test "cancelled and not_cancelled split the games, those with no status counting as not cancelled" do
    a = game(1, game_status: "中止")
    b = game(2, game_status: "試合終了")
    c = game(3, game_status: nil)
    scope = Game.where(id: [ a.id, b.id, c.id ])

    assert_equal [ a.id ], scope.cancelled.pluck(:id)
    assert_equal [ b.id, c.id ].sort, scope.not_cancelled.pluck(:id).sort
  end

  test "cancelled_last puts a cancelled game after its replay of the same round" do
    cancelled = game(1, game_status: "中止")
    replay = Game.create!(season: @season, team0: @alpha, team1: @beta, played_on: "2026-05-09", game_number: 1, game_status: "試合終了")

    assert_equal [ replay, cancelled ], Game.where(id: [ cancelled.id, replay.id ]).cancelled_last.order(:id).to_a
    assert_equal replay, Game.where(id: [ cancelled.id, replay.id ]).cancelled_last.first
  end

  test "record_cancellation marks the game between the teams on that date, either way round, and clears the score" do
    scheduled = game(1, game_status: "試合前")
    voided = game(2, game_status: "試合終了", team0_score: 2, team1_score: 2)

    result = Game.record_cancellation(season: @season, team_ids: [ @beta.id, @alpha.id ], played_on: Date.new(2026, 5, 1))
    Game.record_cancellation(season: @season, team_ids: [ @alpha.id, @beta.id ], played_on: Date.new(2026, 5, 2), status: "ノーゲーム")

    assert_equal scheduled, result
    assert_equal [ "中止", nil, nil ], [ scheduled.reload.game_status, scheduled.team0_score, scheduled.team1_score ]
    assert_equal [ "ノーゲーム", nil, nil ], [ voided.reload.game_status, voided.team0_score, voided.team1_score ]
  end

  test "record_cancellation finds the game by its Scorebook id first" do
    moved = game(1, game_status: "試合前", scorebook_game_id: 2026050101)

    assert_equal moved, Game.record_cancellation(season: @season, team_ids: [ @alpha.id, @beta.id ], played_on: Date.new(2026, 6, 1), scorebook_game_id: 2026050101)
    assert moved.reload.cancelled?
  end

  test "record_cancellation adds nothing for a game we do not have, and leaves other games alone" do
    other = game(1, game_status: "試合前")
    count = Game.count

    assert_nil Game.record_cancellation(season: @season, team_ids: [ @alpha.id, @beta.id ], played_on: Date.new(2026, 5, 9))
    assert_nil Game.record_cancellation(season: seasons(:two), team_ids: [ @alpha.id, @beta.id ], played_on: Date.new(2026, 5, 1))
    assert_equal count, Game.count
    assert_equal "試合前", other.reload.game_status
  end
end
