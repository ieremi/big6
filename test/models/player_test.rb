require "test_helper"

class PlayerTest < ActiveSupport::TestCase
  test "hands_label combines pitching and batting hands" do
    assert_equal "右投左打", Player.new(pitching_hand: "右", batting_hand: "左").hands_label
  end

  test "hands_label shows whichever hand is known" do
    assert_equal "左投", Player.new(pitching_hand: "左").hands_label
    assert_equal "両打", Player.new(batting_hand: "両").hands_label
    assert_equal "", Player.new.hands_label
  end
end
