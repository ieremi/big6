require "test_helper"

class GameMemberTest < ActiveSupport::TestCase
  def member(name, **attributes)
    GameMember.new({ player: Player.new(name: name) }.merge(attributes))
  end

  test "roster_order puts staff first by seniority, then starters by batting order, then the rest by uniform number" do
    members = [
      member("控え二", uniform_number: 20),
      member("五番", role: "外野手", batting_order: 5, uniform_number: 8),
      member("助監督", role: "助監督", uniform_number: 40),
      member("控え一", uniform_number: 12),
      member("一番", role: "遊撃手", batting_order: 1, uniform_number: 6),
      member("監督", role: "監督", uniform_number: 30),
      member("部長", role: "部長"),
      member("背番号なし")
    ]

    assert_equal %w[部長 監督 助監督 一番 五番 控え一 控え二 背番号なし], GameMember.roster_order(members).map { |m| m.player.name }
  end
end
