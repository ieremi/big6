require "test_helper"

class Admin::SuggestionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @hosei = University.create!(name: "法政大学", short_name: "法大", slug: "hosei", position: 14)
    @game = Game.create!(season: seasons(:two), team0: universities(:one), team1: @hosei, played_on: "2026-08-17", game_number: 2,
      team0_score: 15, team1_score: 10, game_status: "試合終了", scorebook_game_id: 2026081702)
    @player = Player.create!(scorebook_id: 20234025, university: @hosei, name: "藤森 康淳", enter_year: 2023)
    @suggestion = FixSuggestion.create!(kind: "misfiled_lines", key: "misfiled_lines 2026081701 4", confidence: "likely",
      university: @hosei, game: @game, scorebook_game_id: 2026081701, played_on: "2026-08-17", candidate_game_ids: [ @game.id ])
    @suggestion.lines.create!(player: @player, scorebook_line_id: 11984, position: "[中]", values: { "pa" => 5, "hits" => 4, "runs" => nil })
  end

  test "only admins can see the suggestions" do
    get admin_suggestions_path
    assert_redirected_to login_path

    sign_in(email: "fan@example.com", admin: false)
    get admin_suggestion_path(@suggestion)
    assert_redirected_to login_path
  end

  test "the list shows the pending suggestions, with counts by status" do
    sign_in

    get admin_suggestions_path

    assert_response :success
    assert_equal "noindex, nofollow", response.headers["X-Robots-Tag"]
    assert_select "a.period-btn.active", "未決定（1）"
    assert_select "tbody tr", 1
    assert_select "tbody td", "別の試合に登録された成績"
  end

  test "a suggestion shows the guessed game, the evidence and the lines, with a value not recorded as -" do
    sign_in

    get admin_suggestion_path(@suggestion)

    assert_response :success
    assert_select "a[href=?]", "https://big6scorebook.jp/game/2026081701"
    assert_select "a[href=?]", "https://big6scorebook.jp/game/2026081702"
    assert_select "tbody td a", "藤森 康淳"
    assert_select "tbody td", "-" # runs, not recorded
    assert_select "button[name=decision][value=approved]", "承認"
    assert_select "button[name=decision][value=discarded]", "却下"
  end

  test "approving records who decided, with the note, and nothing else changes" do
    admin = sign_in

    patch admin_suggestion_path(@suggestion), params: { decision: "approved", note: "4安打を確認" }

    assert_redirected_to admin_suggestions_path(status: "pending")
    @suggestion.reload
    assert_equal [ "approved", admin, "4安打を確認" ], [ @suggestion.status, @suggestion.decided_by, @suggestion.note ]
    assert_equal 0, BattingLine.count
  end

  test "a decided suggestion can be taken back, and an unknown decision changes nothing" do
    sign_in
    @suggestion.decide!("discarded", user: nil)

    patch admin_suggestion_path(@suggestion), params: { decision: "pending" }
    assert_equal "pending", @suggestion.reload.status

    patch admin_suggestion_path(@suggestion), params: { decision: "delete" }
    assert_redirected_to admin_suggestion_path(@suggestion)
    assert_equal "pending", @suggestion.reload.status
  end
end
