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
end
