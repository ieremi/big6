require "test_helper"

class SeniorAppearancesTest < ActiveSupport::TestCase
  setup do
    @game = Game.where(season: seasons(:one)).order(:played_on).first
    @alpha = @game.team0
  end

  def senior(id, **attrs)
    Player.create!(scorebook_id: id, university: @alpha, name: "選手#{id}", enter_year: 2023, role: "選手",
      enrollment_status: Player::ACTIVE_ENROLLMENT_STATUS, **attrs)
  end

  test "counts the seniors who started, who were only on a roster, and who never were, by university" do
    batter = senior(1)
    pitcher = senior(2)
    bench = senior(3)
    senior(4) # never on a roster
    GameMember.create!(game: @game, player: batter, university: @alpha, batting_order: 3, fielding_position: "中")
    GameMember.create!(game: @game, player: pitcher, university: @alpha, fielding_position: "投") # the starting pitcher, with a DH
    GameMember.create!(game: @game, player: bench, university: @alpha)

    row = SeniorAppearances.new(2023).rows.sole

    assert_equal [ @alpha, 2, 1, 1, 4 ], [ row.university, row.started, row.bench, row.none, row.total ]
    assert_in_delta 0.5, row.share(:started)
  end

  test "leaves out managers, other years, and players who have left the club" do
    senior(1)
    senior(2, role: "マネージャー")
    senior(3, enter_year: 2024)
    senior(4, enrollment_status: 3)

    assert_equal 1, SeniorAppearances.new(2023).total.total
  end
end
