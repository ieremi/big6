require "test_helper"

class MatchupsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @alpha = universities(:one)
    @beta = universities(:two)
    @game = games(:one)
  end

  def add_member(scorebook_id, university, name, **attributes)
    player = Player.create!(scorebook_id: scorebook_id, university: university, name: name, enter_year: 2023, role: "選手", enrollment_status: 1)
    GameMember.create!({ game: @game, player: player, university: university }.merge(attributes))
  end

  test "game page lists each team's bench members in collapsible sections, closed by default" do
    add_member(1, @alpha, "落合 智哉", uniform_number: 27, role: "捕手")
    add_member(2, @beta, "今津 慶介", uniform_number: 6, role: "遊撃手")

    get matchup_game_url("alpha", "beta", 2026, "spring", 1)

    assert_response :success
    assert_select "[data-controller=decade-fold] details.decade[data-decade-fold-target=decade]", 2
    assert_select "details.decade[open]", 0
    assert_select "details.decade summary", text: /#{Regexp.escape(@alpha.short_name)}（1人）/
    assert_select "details.decade summary", text: /#{Regexp.escape(@beta.short_name)}（1人）/
    assert_select "details.decade a[href=?]", player_path(Player.find_by!(scorebook_id: 1)), text: "落合 智哉"
    assert_select "details.decade a[href=?]", player_path(Player.find_by!(scorebook_id: 2)), text: "今津 慶介"
  end

  test "game page has expand-all and collapse-all buttons with keyboard shortcuts" do
    add_member(1, @alpha, "落合 智哉")

    get matchup_game_url("alpha", "beta", 2026, "spring", 1)

    assert_select "button[data-action='decade-fold#openAll'][data-shortcut=u]", text: /すべて開く/
    assert_select "button[data-action='decade-fold#closeAll'][data-shortcut=f]", text: /すべて閉じる/
  end

  test "game page shows only the team that has a roster" do
    add_member(1, @alpha, "落合 智哉")

    get matchup_game_url("alpha", "beta", 2026, "spring", 1)

    assert_select "details.decade", 1
  end

  test "game page has no bench section or fold buttons when no roster is stored" do
    get matchup_game_url("alpha", "beta", 2026, "spring", 1)

    assert_response :success
    assert_select "details.decade", 0
    assert_select "button[data-action='decade-fold#openAll']", 0
    assert_no_match "ベンチ入りメンバー", response.body
  end
end
