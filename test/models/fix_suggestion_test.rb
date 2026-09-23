require "test_helper"

class FixSuggestionTest < ActiveSupport::TestCase
  # Scorebook's team ids: 1 waseda, 2 keio, 4 hosei, 5 tokyo (ScorebookSync::SCOREBOOK_TEAM_SLUGS).
  setup do
    @waseda = University.create!(name: "早稲田大学", short_name: "早大", slug: "waseda", position: 11)
    @keio = University.create!(name: "慶應義塾大学", short_name: "慶大", slug: "keio", position: 12)
    @hosei = University.create!(name: "法政大学", short_name: "法大", slug: "hosei", position: 14)
    @tokyo = University.create!(name: "東京大学", short_name: "東大", slug: "tokyo", position: 15)
    @season = Season.create!(year: 2025, term: "autumn")
    @filed_under = create_game(@tokyo, @keio, 2025100501)
    @real = create_game(@waseda, @hosei, 2025100502)
    @fujimori = Player.create!(scorebook_id: 20234025, university: @hosei, name: "藤森 康淳", enter_year: 2023)
    @matsushita = Player.create!(scorebook_id: 20224019, university: @hosei, name: "松下 歩叶", enter_year: 2022)
  end

  def create_game(team0, team1, scorebook_game_id, day: "2025-10-05")
    Game.create!(season: @season, team0: team0, team1: team1, played_on: day, game_number: 2,
      team0_score: 1, team1_score: 0, game_status: "試合終了", scorebook_game_id: scorebook_game_id)
  end

  # A line of a hosei player, filed under the tokyo v keio game unless told otherwise.
  def line(line_id, game_id: 2025100501, sides: [ 5, 2 ], team: 4, day: "2025-10-05", hits: 4)
    ScorebookMemberStats::Line.new(scorebook_game_id: game_id, played_on: Date.parse(day), line_id: line_id, team_id: team,
      game_team_ids: sides, round: "2回戦", position: "[中]", values: { pa: 5, ab: 5, hits: hits, runs: nil })
  end

  test "a line whose team is neither side of its game suggests the team's game that day" do
    FixSuggestion.record_from(@fujimori, [ line(11984) ])

    suggestion = FixSuggestion.sole
    assert_equal [ "misfiled_lines", "pending", "likely", @hosei, @real, 2025100501, [ @real.id ] ],
      [ suggestion.kind, suggestion.status, suggestion.confidence, suggestion.university, suggestion.game, suggestion.scorebook_game_id, suggestion.candidate_game_ids ]
    assert_equal @filed_under, suggestion.filed_under_game
    line = suggestion.lines.sole
    assert_equal [ @fujimori, 11984, "[中]", 4, nil ], [ line.player, line.scorebook_line_id, line.position, line.value(:hits), line.value(:runs) ]
  end

  test "teammates' lines gather in the one suggestion, and a line is recorded once" do
    FixSuggestion.record_from(@fujimori, [ line(11984) ])
    FixSuggestion.record_from(@matsushita, [ line(11985, hits: 1) ])
    FixSuggestion.record_from(@fujimori, [ line(11984) ])

    assert_equal 1, FixSuggestion.count
    assert_equal [ 11984, 11985 ], FixSuggestion.sole.lines.map(&:scorebook_line_id)
  end

  test "lines filed under their own game suggest nothing" do
    FixSuggestion.record_from(@fujimori, [ line(12000, game_id: 2025100502, sides: [ 1, 4 ]) ])

    assert_equal 0, FixSuggestion.count
  end

  test "with more than one game of the team that day, the guess is left for review" do
    create_game(@hosei, @tokyo, 2025100503)

    FixSuggestion.record_from(@fujimori, [ line(11984) ])

    suggestion = FixSuggestion.sole
    assert_equal "needs_review", suggestion.confidence
    assert_nil suggestion.game
    assert_equal 2, suggestion.candidate_game_ids.size
  end

  test "a game whose two sides are the same university is suggested for review" do
    game = create_game(@waseda, @waseda, 1981053001, day: "1981-05-30")

    FixSuggestion.record_from(@fujimori, [ line(5001, game_id: 1981053001, sides: [ 1, 1 ], team: 2, day: "1981-05-30") ])

    suggestion = FixSuggestion.sole
    assert_equal [ "same_team_game", "needs_review", game, @keio ], [ suggestion.kind, suggestion.confidence, suggestion.game, suggestion.university ]
  end

  test "a discarded suggestion isn't made again" do
    FixSuggestion.record_from(@fujimori, [ line(11984) ])
    FixSuggestion.sole.decide!("discarded", user: nil)

    FixSuggestion.record_from(@matsushita, [ line(11985) ])

    assert_equal [ "discarded" ], FixSuggestion.pluck(:status)
  end

  test "the hits check compares the lines' hits with the team's hits on the guessed game's scoreboard" do
    @season.update!(scorebook_games: [ { "id" => 2025100502, "hitsTotalTop" => "13", "hitsTotalBottom" => "5" } ])
    FixSuggestion.record_from(@fujimori, [ line(11984) ])
    FixSuggestion.record_from(@matsushita, [ line(11985, hits: 1) ])

    assert_equal({ lines: 5, scoreboard: 5 }, FixSuggestion.sole.hits_check) # hosei is the bottom side
  end

  test "the roster check counts the lines' players on the guessed game's roster" do
    GameMember.create!(game: @real, player: @fujimori, university: @hosei)
    GameMember.create!(game: @real, player: @matsushita, university: @hosei)
    FixSuggestion.record_from(@fujimori, [ line(11984) ])

    assert_equal({ on_roster: 1, lines: 1, roster: 2 }, FixSuggestion.sole.roster_check)
    assert_equal 0, FixSuggestion.sole.our_lines_count
  end

  def approved_suggestion
    FixSuggestion.record_from(@fujimori, [ line(11984) ])
    FixSuggestion.record_from(@matsushita, [ line(11985, hits: 1) ])
    suggestion = FixSuggestion.sole
    suggestion.decide!("approved", user: nil)
    suggestion
  end

  test "applying an approved suggestion adds its lines to the guessed game, as the suggestion's" do
    suggestion = approved_suggestion
    admin = User.create!(email: "admin@example.com", admin: true)

    assert_equal 2, suggestion.apply!(user: admin)

    lines = BattingLine.where(game: @real).order(:player_id)
    assert_equal [ @fujimori, @matsushita ].sort_by(&:id), lines.map(&:player)
    fujimori = lines.find_by(player: @fujimori)
    assert_equal [ @hosei, suggestion, "[中]", 5, 5, 4, 0, 4 ], [ fujimori.university, fujimori.fix_suggestion, fujimori.position, fujimori.pa, fujimori.ab, fujimori.hits, fujimori.runs, fujimori.total_bases ]
    assert suggestion.applied?
    assert_equal admin, suggestion.reload.applied_by
    assert suggestion.applied_at
  end

  test "applying skips a player who already has a line in the game, and again adds only the lines gathered since" do
    suggestion = approved_suggestion
    BattingLine.create!(game: @real, player: @matsushita, university: @hosei, pa: 4, ab: 4, hits: 1) # imported from Scorebook

    assert_equal 1, suggestion.apply!(user: nil)
    assert_nil BattingLine.find_by(game: @real, player: @matsushita).fix_suggestion

    teammate = Player.create!(scorebook_id: 20234026, university: @hosei, name: "中村 騎士", enter_year: 2024)
    FixSuggestion.record_from(teammate, [ line(11986, hits: 2) ])
    assert_equal [ teammate ], suggestion.reload.lines_to_apply.map(&:player)
    assert_equal 1, suggestion.apply!(user: nil)
    assert_equal 0, suggestion.apply!(user: nil)
  end

  test "only an approved suggestion with its game guessed can be applied" do
    FixSuggestion.record_from(@fujimori, [ line(11984) ])
    suggestion = FixSuggestion.sole

    assert_raises(FixSuggestion::NotAllowed) { suggestion.apply!(user: nil) }

    suggestion.update!(status: "approved", game: nil)
    assert_raises(FixSuggestion::NotAllowed) { suggestion.apply!(user: nil) }
    assert_equal 0, BattingLine.count
  end

  test "taking an application back removes only the lines it added, and until then the decision can't change" do
    suggestion = approved_suggestion
    BattingLine.create!(game: @real, player: @matsushita, university: @hosei, pa: 4, ab: 4, hits: 1)
    suggestion.apply!(user: nil)

    assert_raises(FixSuggestion::NotAllowed) { suggestion.decide!("discarded", user: nil) }
    assert_raises(FixSuggestion::NotAllowed) { suggestion.decide!("pending", user: nil) }

    assert_equal 1, suggestion.unapply!
    assert_equal [ @matsushita ], BattingLine.where(game: @real).map(&:player)
    assert_not suggestion.applied?
    assert_nil suggestion.reload.applied_at
    suggestion.decide!("discarded", user: nil)
    assert_equal "discarded", suggestion.status
  end

  test "applying publishes a notice about the game, in the default words unless given others" do
    suggestion = approved_suggestion

    suggestion.apply!(user: nil)

    notice = Announcement.sole
    assert_equal suggestion, notice.fix_suggestion
    assert_equal @real, notice.game
    assert_equal "2025年秋季 早大 vs 法大 2回戦 の法大の打撃成績を補いました", notice.title
    assert_match "2025年10月5日の早大 vs 法大 2回戦で、法大の打撃成績が当サイトに入っていなかったため、2人分を補いました。", notice.body
    assert_match "この試合（https://big6scorebook.jp/game/2025100502）の法大の打撃成績が同じ日の別の試合（https://big6scorebook.jp/game/2025100501）に登録されている", notice.body

    suggestion.unapply!
    suggestion.apply!(user: nil, title: "お詫び", body: "補いました。")
    assert_equal [ "お詫び", "補いました。" ], Announcement.pluck(:title, :body).sole
  end

  test "applying again updates the same notice, which keeps when it was published, and taking it back deletes it" do
    suggestion = approved_suggestion
    suggestion.lines.last.destroy # only 藤森's line gathered yet
    published = 2.days.ago
    suggestion.apply!(user: nil, now: published)
    assert_match "1人分を補いました", Announcement.sole.body

    teammate = Player.create!(scorebook_id: 20234026, university: @hosei, name: "中村 騎士", enter_year: 2024)
    FixSuggestion.record_from(teammate, [ line(11986, hits: 2) ])
    assert_match "2人分を補いました", suggestion.reload.default_announcement.last
    suggestion.apply!(user: nil)

    notice = Announcement.sole
    assert_match "2人分を補いました", notice.body
    assert_in_delta published, notice.published_at, 1
    assert notice.revised?

    suggestion.unapply!
    assert_equal 0, Announcement.count
  end

  test "a decision records who made it and when, and can be taken back" do
    FixSuggestion.record_from(@fujimori, [ line(11984) ])
    suggestion = FixSuggestion.sole
    admin = User.create!(email: "admin@example.com", admin: true)

    suggestion.decide!("approved", user: admin, note: "打者全員そろった")
    assert_equal [ "approved", admin, "打者全員そろった" ], [ suggestion.status, suggestion.decided_by, suggestion.note ]
    assert suggestion.decided_at

    suggestion.decide!("pending", user: admin)
    assert_equal [ "pending", nil, nil, "打者全員そろった" ], [ suggestion.status, suggestion.decided_by, suggestion.decided_at, suggestion.note ]
    assert_raises(ArgumentError) { suggestion.decide!("maybe", user: admin) }
  end
end
