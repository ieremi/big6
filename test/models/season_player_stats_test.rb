require "test_helper"

class SeasonPlayerStatsTest < ActiveSupport::TestCase
  setup do
    @game = Game.where(season: seasons(:one)).order(:played_on).first
  end

  def batter(id, pa:, ab:, hits:)
    player = Player.create!(scorebook_id: id, university: @game.team0, name: "打者#{id}", enter_year: 2023, role: "選手")
    BattingLine.create!(game: @game, player:, university: @game.team0, pa:, ab:, hits:)
  end

  def ranks(stats)
    stats.rows("batting").map { |row| [ row.rank, row.player.name ] }
  end

  test "players with the same average shown share a place, and the next comes after both" do
    batter(1, pa: 4, ab: 3, hits: 1)
    batter(2, pa: 4, ab: 3, hits: 1)
    batter(3, pa: 4, ab: 4, hits: 1)

    assert_equal [ [ 1, "打者1" ], [ 1, "打者2" ], [ 3, "打者3" ] ], ranks(SeasonPlayerStats.new(seasons(:one), top: 10))
  end

  test "the top places hold ties past the limit, and everyone is shown without one" do
    (1..3).each { |id| batter(id, pa: 4, ab: 4, hits: 4 - id) } # .750 .500 .250
    batter(4, pa: 4, ab: 4, hits: 2) # .500 again
    batter(5, pa: 1, ab: 1, hits: 1) # 1.000, short of the minimum

    assert_equal [ [ 1, "打者1" ], [ 2, "打者2" ], [ 2, "打者4" ] ], ranks(SeasonPlayerStats.new(seasons(:one), top: 2))
    assert_equal [ nil, "打者5" ], ranks(SeasonPlayerStats.new(seasons(:one))).last
    assert_equal 5, SeasonPlayerStats.new(seasons(:one), top: 2).count("batting")
  end
end
