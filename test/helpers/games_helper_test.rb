require "test_helper"

class GamesHelperTest < ActionView::TestCase
  test "a list's games are counted by status, in a fixed order, leaving out the statuses no game has" do
    games = %w[scheduled finished cancelled in_progress scheduled no_game finished].map { |status| Game.new(game_status: status) }

    assert_equal "終了2・試合中1・予定2・中止1・ノーゲーム1", games_count_label(games)
    assert_equal "終了10", games_status_count_label("finished" => 10)
  end

  test "an empty list is 0試合" do
    assert_equal "0試合", games_count_label([])
    assert_equal "0試合", games_status_count_label({})
  end
end
