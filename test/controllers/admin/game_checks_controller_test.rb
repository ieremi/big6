require "test_helper"

class Admin::GameChecksControllerTest < ActionDispatch::IntegrationTest
  # The fixtures have alpha v beta on 2026-08-10 in both seasons: a university
  # with two games on one day, found twice (once for each side).
  def same_day_key
    "same_day #{universities(:one).id} 2026-08-10"
  end

  test "only admins see the findings" do
    get admin_game_checks_path
    assert_redirected_to login_path
  end

  test "the findings are listed by kind, with links to the games" do
    sign_in

    get admin_game_checks_path

    assert_response :success
    assert_select "details#same_day summary", "同じ日に同じ大学の試合が2つ（2件）"
    assert_select "details#same_team summary", "両チームが同じ大学（0件）"
    assert_select "details#same_day h3", "Alphaが2026-08-10に2試合"
    assert_select "details#same_day a[href=?]", matchup_game_path("alpha", "beta", 2026, "spring", 1)
  end

  test "a finding marked fine leaves the list, with its note, until taken back; the games don't change" do
    admin = sign_in
    games_before = Game.order(:id).pluck(:id, :played_on, :game_number)

    post admin_review_game_check_path, params: { key: same_day_key, note: "春と秋の同日（テスト用）", kind: "same_day" }
    assert_redirected_to admin_game_checks_path(anchor: "same_day")
    assert_equal [ "春と秋の同日（テスト用）", admin ], GameCheckReview.pluck(:note, :reviewed_by_id).map { |note, id| [ note, User.find(id) ] }.sole

    get admin_game_checks_path
    assert_select "details#same_day summary", "同じ日に同じ大学の試合が2つ（1件、確認済み 1件）"
    assert_select "details#same_day h3", 1

    get admin_game_checks_path(reviewed: 1)
    assert_select "details#same_day h3", 2
    assert_select "details#same_day p.muted", /確認済み（正常）：春と秋の同日（テスト用）/

    post admin_review_game_check_path, params: { key: same_day_key, remove: 1, kind: "same_day" }
    assert_equal 0, GameCheckReview.count
    assert_equal games_before, Game.order(:id).pluck(:id, :played_on, :game_number)
  end
end
