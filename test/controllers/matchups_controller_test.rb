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

  test "game page's bench tables sort in the browser, roles and positions in baseball order" do
    add_member(1, @alpha, "落合 智哉", role: "捕手", fielding_position: "捕")
    add_member(2, @alpha, "堀井 哲也", role: "監督")
    add_member(3, @alpha, "山田 太郎", role: "学生コーチ")

    get matchup_game_url("alpha", "beta", 2026, "spring", 1)

    assert_select "details.decade table[data-controller=sortable-table]", 1
    %w[U N Y T Q Z].each do |key|
      assert_select "details.decade th.sortable button[data-action='sortable-table#sort'][data-shortcut=#{key}]", 1
    end
    assert_select "td[data-sort-value='2']", text: "監督"
    assert_select "td[data-sort-value='6']", text: "捕手"
    assert_select "td[data-sort-value='13']", text: "学生コーチ"
    assert_select "td[data-sort-value='1']", text: "捕"
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

  # ---- the game's status on its page

  def status_tag
    css_select("p.muted .game-status").map { |tag| [ tag["data-status"], tag.text ] }
  end

  test "game page shows the game's status as a tag" do
    { "scheduled" => "試合前", "in_progress" => "試合中" }.each do |status, label|
      @game.update!(game_status: status)

      get matchup_game_url("alpha", "beta", 2026, "spring", 1)

      assert_equal [ [ status, label ] ], status_tag
    end

    @game.update!(game_status: "finished", team0_score: 4, team1_score: 2)
    get matchup_game_url("alpha", "beta", 2026, "spring", 1)

    assert_equal [ [ "finished", "試合終了" ] ], status_tag
    assert_select ".score", text: "4-2"
  end

  test "game page says what the status means where there is no scoreboard" do
    @game.update!(game_status: "scheduled")
    get matchup_game_url("alpha", "beta", 2026, "spring", 1)
    assert_select "p.muted", text: /この試合はまだ行われていません/

    @game.update!(game_status: "in_progress")
    get matchup_game_url("alpha", "beta", 2026, "spring", 1)
    assert_select "p.muted", text: /試合中です。詳細データはまだありません/
    assert_select "p.muted", text: /まだ行われていません/, count: 0

    @game.update!(game_status: "finished", team0_score: 1, team1_score: 0)
    get matchup_game_url("alpha", "beta", 2026, "spring", 1)
    assert_select "p.muted", text: /詳細データはありません/
  end

  test "game page shows the status as stored, not one guessed from the date" do
    @game.update!(played_on: Date.current - 5, game_status: "scheduled") # not yet updated by the sync

    get matchup_game_url("alpha", "beta", 2026, "spring", 1)

    assert_equal [ [ "scheduled", "試合前" ] ], status_tag
  end
end
