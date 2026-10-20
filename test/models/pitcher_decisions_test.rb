require "test_helper"

class PitcherDecisionsTest < ActiveSupport::TestCase
  # 2026-10-19's 慶大0-5明大 3回戦, with its win and loss the wrong way round, as Scorebook had them.
  setup do
    @keio = University.create!(name: "慶應義塾大学", short_name: "慶大", slug: "keio", position: 12)
    @meiji = University.create!(name: "明治大学", short_name: "明大", slug: "meiji", position: 13)
    @season = Season.create!(year: 2026, term: "autumn")
    @game = Game.create!(season: @season, team0: @keio, team1: @meiji, played_on: "2026-10-19", game_number: 3,
      team0_score: 0, team1_score: 5, game_status: "試合終了", scorebook_game_id: 2026101901)
    @watanabe = Player.create!(scorebook_id: 20232016, university: @keio, name: "渡辺 和大", enter_year: 2023)
    @mizuno = Player.create!(scorebook_id: 20242046, university: @keio, name: "水野 敬太", enter_year: 2024)
    @urahisa = Player.create!(scorebook_id: 20243005, university: @meiji, name: "浦久 響", enter_year: 2024)
    pitch(@watanabe, @keio, wins: 1)
    pitch(@mizuno, @keio)
    pitch(@urahisa, @meiji, losses: 1)
  end

  def pitch(player, university, wins: 0, losses: 0, game: @game)
    PitchingLine.create!(game: game, player: player, university: university, wins: wins, losses: losses)
  end

  # [wins, losses] of each pitcher's line, 渡辺, 水野, 浦久.
  def decisions
    [ @watanabe, @mizuno, @urahisa ].map { |player| PitchingLine.find_by!(game: @game, player: player).values_at(:wins, :losses) }
  end

  def suggestion(status: "approved")
    FixSuggestion.record_pitcher_decisions!
    FixSuggestion.sole.tap { |found| found.update!(status: status) }
  end

  def admin
    @admin ||= User.create!(email: "admin@example.com", admin: true)
  end

  # ---- finding and moving them

  test "a win on the side that lost is its loss, and a loss on the side that won its win" do
    rows = [ { university_id: @keio.id, wins: 1, losses: 0 }, { university_id: @meiji.id, wins: 0, losses: 1 } ]

    assert_equal [ [ 0, 1 ], [ 1, 0 ] ], PitcherDecisions.on_their_sides(@game, rows).map { |row| row.values_at(:wins, :losses) }
  end

  test "a second win, on the side that lost, is its loss, and a draw's decisions are left alone" do
    rows = [ { university_id: @keio.id, wins: 1, losses: 0 }, { university_id: @meiji.id, wins: 1, losses: 0 } ]
    assert_equal [ [ 0, 1 ], [ 1, 0 ] ], PitcherDecisions.on_their_sides(@game, rows).map { |row| row.values_at(:wins, :losses) }

    @game.update!(team0_score: 5)
    assert_equal rows, PitcherDecisions.on_their_sides(@game, rows)
  end

  test "the games with a decision on the wrong side are found from the stored lines" do
    right = Game.create!(season: @season, team0: @keio, team1: @meiji, played_on: "2026-10-18", game_number: 2,
      team0_score: 3, team1_score: 7, game_status: "試合終了", scorebook_game_id: 2026101802)
    pitch(@urahisa, @meiji, wins: 1, game: right)
    pitch(@watanabe, @keio, losses: 1, game: right)

    assert_equal [ @game.id ], PitcherDecisions.misplaced_game_ids
  end

  test "the notice names the pitchers as moved, and as Scorebook has them" do
    title, body = PitcherDecisions.new(@game).notice

    assert_equal "2026年秋季 慶大 vs 明大 3回戦 の勝利投手・敗戦投手を直しました", title
    assert_equal [
      "2026年10月19日の慶大 vs 明大 3回戦（明大が5-0で勝利）で、勝利投手を浦久 響（明大）、敗戦投手を渡辺 和大（慶大）としました。",
      "当サイトの成績の元にしている Scorebook（東京六大学野球 公式記録室）の記録（https://big6scorebook.jp/game/2026101901）では、" \
        "勝利投手が渡辺 和大（慶大）、敗戦投手が浦久 響（明大）になっていました。勝利投手は勝ったチーム（明大）の、敗戦投手は負けたチーム（慶大）の投手のはずなので、勝ちと負けを入れ替えました。"
    ].join("\n"), body
  end

  # ---- the suggestion

  test "the nightly check suggests the game for review once, and never again once discarded" do
    made = FixSuggestion.record_pitcher_decisions!

    suggestion = FixSuggestion.sole
    assert_equal [ suggestion ], made
    assert_equal [ "pitcher_decisions", "pending", @game, 2026101901, @game.played_on, "pitcher_decisions 2026101901" ],
      [ suggestion.kind, suggestion.status, suggestion.game, suggestion.scorebook_game_id, suggestion.played_on, suggestion.key ]
    assert_equal [ [ 1, 0 ], [ 0, 0 ], [ 0, 1 ] ], decisions # nothing changed

    suggestion.decide!("discarded", user: admin)
    assert_empty FixSuggestion.record_pitcher_decisions!
    assert_equal "discarded", FixSuggestion.sole.status
  end

  test "only an approved one is applied, moving the decisions and publishing the notice" do
    pending = suggestion(status: "pending")
    assert_raises(FixSuggestion::NotAllowed) { pending.apply!(user: admin) }

    approved = suggestion
    assert_equal 2, approved.apply!(user: admin)

    assert_equal [ [ 0, 1 ], [ 0, 0 ], [ 1, 0 ] ], decisions
    assert approved.applied?
    assert_equal "2026年秋季 慶大 vs 明大 3回戦 の勝利投手・敗戦投手を直しました", approved.announcement.title
    assert_includes approved.announcement.body, "では、勝利投手が渡辺 和大（慶大）、敗戦投手が浦久 響（明大）になっていました。"
    assert_equal @game, approved.announcement.game
    assert_raises(FixSuggestion::NotAllowed) { approved.decide!("pending", user: admin) }
  end

  test "taking it back imports the game again and deletes the notice, and changes nothing if that fails" do
    applied = suggestion.tap { |found| found.apply!(user: admin) }

    stub_method(GameStatsImport, :call, ->(*) { { games: 0, failed: 1 } }) do
      assert_raises(FixSuggestion::NotAllowed) { applied.unapply! }
    end
    assert applied.reload.applied?
    assert_not_nil applied.announcement

    imported = nil
    restore = lambda do |games, **|
      imported = games
      PitchingLine.where(game: @game, player: @watanabe).update_all(wins: 1, losses: 0)
      PitchingLine.where(game: @game, player: @urahisa).update_all(wins: 0, losses: 1)
      { games: 1 }
    end
    stub_method(GameStatsImport, :call, restore) { applied.unapply! }

    assert_equal [ @game ], imported
    assert_not applied.reload.applied?
    assert_empty Announcement.all
    assert_equal [ [ 1, 0 ], [ 0, 0 ], [ 0, 1 ] ], decisions
  end

  test "once Scorebook has the decisions right, an undecided suggestion is not needed" do
    pending = suggestion(status: "pending")
    PitchingLine.where(game: @game, player: @watanabe).update_all(wins: 0, losses: 1)
    PitchingLine.where(game: @game, player: @urahisa).update_all(wins: 1, losses: 0)

    FixSuggestion.classify_undecided!

    assert_equal "not_needed", pending.reload.status
  end
end
