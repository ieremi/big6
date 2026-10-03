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

  test "game page's bench tables give each member's faculty, linked to the players of that faculty" do
    member = add_member(1, @alpha, "落合 智哉", role: "捕手")
    member.player.update!(faculty: "商")
    add_member(2, @alpha, "堀井 哲也", role: "監督") # no faculty

    get matchup_game_url("alpha", "beta", 2026, "spring", 1)

    assert_select "details.decade th.sortable button", text: /\A学部 B/
    assert_equal %w[背番号 氏名 学年 学部 役割 打順 守備], css_select("details.decade thead th").map { |th| th.text.split.first }
    assert_select "details.decade td a[href=?]", players_path(faculty: "商"), text: "商"
  end

  test "game page's bench tables sort in the browser, roles and positions in baseball order" do
    add_member(1, @alpha, "落合 智哉", role: "捕手", fielding_position: "捕")
    add_member(2, @alpha, "堀井 哲也", role: "監督")
    add_member(3, @alpha, "山田 太郎", role: "学生コーチ")

    get matchup_game_url("alpha", "beta", 2026, "spring", 1)

    assert_select "details.decade table[data-controller=sortable-table]", 1
    %w[U N Y B T Q Z].each do |key|
      assert_select "details.decade th.sortable button[data-action='sortable-table#sort'][data-shortcut=#{key}]", 1
    end
    assert_select "td[data-sort-value='2']", text: "監督"
    assert_select "td[data-sort-value='6']", text: "捕手"
    assert_select "td[data-sort-value='13']", text: "学生コーチ"
    assert_select "td[data-sort-value='1']", text: "捕"
  end

  test "game page marks who played once the box score is in, and dims the players who didn't" do
    batter = add_member(1, @alpha, "落合 智哉", uniform_number: 27)
    pitcher = add_member(2, @alpha, "今津 慶介", uniform_number: 18)
    add_member(3, @alpha, "山田 太郎", uniform_number: 30)
    add_member(4, @alpha, "堀井 哲也", role: "監督")
    BattingLine.create!(game: @game, player: batter.player, university: @alpha, pa: 0)
    PitchingLine.create!(game: @game, player: pitcher.player, university: @alpha, outs: 3)

    get matchup_game_url("alpha", "beta", 2026, "spring", 1)

    assert_select "details.decade summary", text: /（4人・出場2人）/
    assert_select "th.sortable button[data-shortcut=P]", text: /出場/
    assert_select "tbody tr:not(.bench-only) td[data-sort-value='0']", text: "✓", count: 2
    assert_select "tbody tr.bench-only", 1
    assert_select "tbody tr.bench-only a", text: "山田 太郎"
  end

  test "game page marks nobody as played while the box score isn't in" do
    add_member(1, @alpha, "落合 智哉")

    get matchup_game_url("alpha", "beta", 2026, "spring", 1)

    assert_select "th", text: /出場/, count: 0
    assert_select "tr.bench-only", 0
    assert_select "details.decade summary", text: /（1人）/
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

  test "game page shows each team's batting lines in Scorebook's order, starters numbered, with a total row" do
    starter = add_member(1, @alpha, "落合 智哉").player
    pinch = add_member(2, @alpha, "山田 太郎").player
    second = add_member(3, @alpha, "今津 慶介").player
    BattingLine.create!(game: @game, player: starter, university: @alpha, position: "[2]", pa: 4, ab: 3, hits: 1, rbi: 2)
    BattingLine.create!(game: @game, player: pinch, university: @alpha, position: "H", pa: 1, ab: 1, hits: 1)
    BattingLine.create!(game: @game, player: second, university: @alpha, position: "[4]6", pa: 4, ab: 4)

    get matchup_game_url("alpha", "beta", 2026, "spring", 1)

    assert_select "h2", text: "打撃成績"
    assert_select "[data-controller=decade-fold] details.decade:not([open]) table.box-score", 1
    assert_select "details.decade summary", text: /#{Regexp.escape(@alpha.short_name)}（3人）/
    rows = css_select("table.box-score tbody tr").map { |row| row.css("td").first(4).map { |cell| cell.text.strip } }
    assert_equal [ [ "1", "[捕]", "落合 智哉", "4" ], [ "", "打", "山田 太郎", "1" ], [ "2", "[二]遊", "今津 慶介", "4" ] ], rows
    assert_select "table.box-score tr.box-score-sub a", text: "山田 太郎"
    assert_select "table.box-score tfoot tr" do |footer|
      assert_equal %w[計 9 8 2], footer.first.css("th, td").first(4).map { |cell| cell.text.strip }
    end
  end

  test "game page shows each team's pitching lines, with the result and innings" do
    starter = add_member(1, @beta, "今津 慶介").player
    reliever = add_member(2, @beta, "落合 智哉").player
    PitchingLine.create!(game: @game, player: starter, university: @beta, started: 1, wins: 1, outs: 20, earned_runs: 1)
    PitchingLine.create!(game: @game, player: reliever, university: @beta, outs: 7)

    get matchup_game_url("alpha", "beta", 2026, "spring", 1)

    assert_select "h2", text: "投手成績"
    rows = css_select("table.box-score tbody tr").map { |row| row.css("td").first(3).map { |cell| cell.text.strip } }
    assert_equal [ [ "今津 慶介", "勝先発", "6 2/3" ], [ "落合 智哉", "", "2 1/3" ] ], rows
    assert_select "table.box-score tfoot td", text: "9"
  end

  test "game page puts the box score after the bench, and u and f open and close both at once" do
    member = add_member(1, @alpha, "落合 智哉")
    BattingLine.create!(game: @game, player: member.player, university: @alpha, position: "[2]", pa: 4)
    PitchingLine.create!(game: @game, player: member.player, university: @alpha, outs: 3)

    get matchup_game_url("alpha", "beta", 2026, "spring", 1)

    headings = css_select("h2.card-heading").map { |heading| heading.text.strip }
    assert_equal %w[ベンチ入りメンバー 打撃成績 投手成績], headings
    assert_select "button[data-action='decade-fold#openAll'][data-shortcut=u][data-shortcut-all]", 2
    assert_select "button[data-action='decade-fold#closeAll'][data-shortcut=f][data-shortcut-all]", 2
  end

  test "game page has no batting or pitching section before the box score is in" do
    get matchup_game_url("alpha", "beta", 2026, "spring", 1)

    assert_select "table.box-score", 0
    assert_select "h2", text: "打撃成績", count: 0
    assert_select "h2", text: "投手成績", count: 0
  end

  test "game page tells each team's changes from its previous game, linked to it" do
    previous = Game.create!(season: @game.season, team0: @alpha, team1: @beta, played_on: @game.played_on - 1, game_number: 2,
      team0_score: 1, team1_score: 0, game_status: "試合終了")
    @game.update!(played_on: previous.played_on + 1)
    old = Player.create!(scorebook_id: 9, university: @alpha, name: "前回の先発", enter_year: 2023, role: "選手", enrollment_status: 1)
    GameMember.create!(game: previous, player: old, university: @alpha, fielding_position: "投")
    add_member(1, @alpha, "落合 智哉", fielding_position: "投")

    get matchup_game_url("alpha", "beta", 2026, "spring", 1)

    assert_select ".roster-diff a[href=?]", matchup_game_path("alpha", "beta", 2026, "spring", 2)
    assert_select ".roster-diff li", text: /スタメンに入った：落合 智哉（投、前回はベンチ外）/
    assert_select ".roster-diff li", text: /スタメンから外れた：前回の先発（前回 投、今回はベンチ外）/
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
