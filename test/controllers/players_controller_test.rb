require "test_helper"

class PlayersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @alpha = universities(:one)
    @beta = universities(:two)
    @ochiai = create_player(20236010, @alpha, "落合 智哉", name_kana: "オチアイ トモヤ", enter_year: 2023, high_school: "東邦", position: "捕手")
    @imazu = create_player(20231007, @beta, "今津 慶介", name_kana: "イマヅ ケイスケ", enter_year: 2023, high_school: "旭川東", position: "遊撃手")
    @old = create_player(19951001, @alpha, "山田 太郎", enter_year: 1995, enrollment_status: 2, high_school: "浦和")
    @coach = create_player(19951099, @alpha, "日野 愛郎", enter_year: nil, role: "部長", enrollment_status: 3)
  end

  def create_player(scorebook_id, university, name, **attributes)
    Player.create!({ scorebook_id: scorebook_id, university: university, name: name, enter_year: 2023, role: "選手", enrollment_status: 1 }.merge(attributes))
  end

  def listed_names
    css_select("tbody tr td:nth-child(2) a").map(&:text)
  end

  test "index lists every player, newest entry year first and those without one last" do
    get players_url

    assert_response :success
    assert_equal [ "落合 智哉", "今津 慶介", "山田 太郎", "日野 愛郎" ], listed_names
    assert_match "4人", response.body
  end

  test "index searches the name with or without the space, the reading, and the high school" do
    { "落合智哉" => [ "落合 智哉" ], "落合 智哉" => [ "落合 智哉" ], "イマヅ" => [ "今津 慶介" ], "浦和" => [ "山田 太郎" ] }.each do |query, expected|
      get players_url, params: { q: query }

      assert_equal expected, listed_names, "searching #{query}"
    end
  end

  test "index search ignores tabs, ideographic spaces, and no-break spaces in names" do
    create_player(20241001, @beta, "佐藤\u00a0花子")
    create_player(20241002, @beta, "鈴木\u3000次郎")
    create_player(20241003, @beta, "高橋\t三郎")

    { "佐藤花子" => "佐藤\u00a0花子", "鈴木 次郎" => "鈴木\u3000次郎", "高橋三郎" => "高橋\t三郎" }.each do |query, expected|
      get players_url, params: { q: query }

      assert_equal [ expected ], listed_names, "searching #{query}"
    end
  end

  test "index treats LIKE wildcards in the keyword literally" do
    get players_url, params: { q: "%" }

    assert_empty listed_names
  end

  test "index filters by university, entry year range, role group, and status" do
    get players_url, params: { university_ids: [ @beta.id ] }
    assert_equal [ "今津 慶介" ], listed_names

    get players_url, params: { start_year: 1990, end_year: 2000 }
    assert_equal [ "山田 太郎" ], listed_names

    get players_url, params: { role: "staff" }
    assert_equal [ "日野 愛郎" ], listed_names

    get players_url, params: { status: "alumni" }
    assert_equal [ "山田 太郎" ], listed_names

    get players_url, params: { status: "active", role: "player", university_ids: [ @alpha.id ] }
    assert_equal [ "落合 智哉" ], listed_names
  end

  test "index ignores unknown filter values" do
    get players_url, params: { role: "bogus", status: "bogus", university_ids: [ "9999" ] }

    assert_response :success
    assert_equal 4, listed_names.size
  end

  test "index paginates and clamps the page number" do
    Player.where.not(id: @ochiai.id).delete_all
    (1..PlayersController::PER_PAGE).each { |i| create_player(30000000 + i, @alpha, "選手#{i.to_s.rjust(3, '0')}", enter_year: 2020) }

    get players_url
    assert_equal PlayersController::PER_PAGE, listed_names.size
    assert_select "nav.pagination a[rel=next]"
    assert_select "nav.pagination a[rel=prev]", false

    get players_url, params: { page: 2 }
    assert_equal [ "選手050" ], listed_names
    assert_select "nav.pagination a[rel=prev]"

    get players_url, params: { page: 99 }
    assert_equal [ "選手050" ], listed_names
  end

  test "show displays the profile and links to Scorebook" do
    get player_url(@ochiai)

    assert_response :success
    assert_select "h1", /落合 智哉/
    assert_match "オチアイ トモヤ", response.body
    assert_match "東邦", response.body
    assert_select "a[href=?]", "https://big6scorebook.jp/member/20236010"
    assert_match "ベンチ入りの記録はありません", response.body
  end

  test "show lists the games the player was on the roster for" do
    game = games(:one)
    GameMember.create!(game: game, player: @ochiai, university: @alpha, uniform_number: 27, grade: 3, role: "捕手", batting_order: 5, fielding_position: "捕")

    get player_url(@ochiai)

    assert_select "table tbody tr", 1
    assert_select "a[href=?]", matchup_game_path("alpha", "beta", 2026, "spring", 1)
    assert_match "27", response.body
  end

  test "show returns 404 for an unknown player" do
    get player_url(id: 1)

    assert_response :not_found
  end

  test "show points its OG image at the player's image" do
    get player_url(@ochiai)

    assert_select "meta[property='og:image'][content=?]", player_og_image_url(@ochiai)
  end

  test "og_image returns a PNG" do
    get player_og_image_url(@ochiai)

    assert_response :success
    assert_equal "image/png", response.media_type
    assert_equal "\x89PNG".b, response.body.b[0, 4]
  end

  test "og_image returns 404 for an unknown player" do
    get player_og_image_url(id: 1)

    assert_response :not_found
  end

  test "show displays season and career stats and the per-game lines" do
    game = games(:one)
    other = Game.create!(season: seasons(:one), team0: @alpha, team1: @beta, played_on: "2026-08-11", game_number: 2)
    BattingLine.create!(game: game, player: @ochiai, university: @alpha, pa: 4, ab: 4, hits: 2, home_runs: 1, rbi: 3)
    BattingLine.create!(game: other, player: @ochiai, university: @alpha, pa: 4, ab: 4, hits: 1)
    PitchingLine.create!(game: game, player: @ochiai, university: @alpha, outs: 10, earned_runs: 3, losses: 1, started: 1)

    get player_url(@ochiai)

    assert_response :success
    assert_select "h2", "打撃成績"
    assert_select "h2", "投手成績"
    assert_select "tr.stats-total td", text: ".375" # 3 hits in 8 at-bats
    assert_select "tr.stats-total td", text: "3 1/3"
    assert_select "details.decade summary", text: /打撃 試合別成績（2試合）/
    assert_select "details.decade summary", text: /投手 試合別成績（1試合）/
    assert_select "button[data-shortcut=u]", text: /すべて開く/
    assert_select "details.decade[open]", 0
  end

  test "show gives OPS next to the batting average, with how the on-base part is worked out" do
    game = games(:one)
    other = Game.create!(season: seasons(:one), team0: @alpha, team1: @beta, played_on: "2026-08-11", game_number: 2)
    BattingLine.create!(game: game, player: @ochiai, university: @alpha, pa: 5, ab: 4, hits: 2, doubles: 1, total_bases: 5, walks: 1)
    BattingLine.create!(game: other, player: @ochiai, university: @alpha, pa: 4, ab: 4, hits: 1, total_bases: 1)

    get player_url(@ochiai)

    assert_select "th", text: "OPS"
    # AB 8, hits 3, walks 1, total bases 6: on-base 4/9, slugging 6/8, OPS 1.194
    assert_select "tr.stats-total td", text: "1.194"
    assert_select "tr.stats-total td", text: ".375"
    assert_select "p.muted", text: /犠飛は含めていません/
  end

  test "show marks games not counted toward stats" do
    playoff = Game.create!(season: seasons(:one), team0: @alpha, team1: @beta, played_on: "2026-06-04", game_number: 5, counted_in_stats: false)
    BattingLine.create!(game: playoff, player: @ochiai, university: @alpha, pa: 4, ab: 4, hits: 4)

    get player_url(@ochiai)

    assert_select ".season-tag", text: "通算に含まず"
    assert_select "tr.stats-total td", text: ".---", count: 0
    assert_select "tr.stats-total td", text: "---" # no counted at-bats, so no average
  end

  test "show has no stats sections for a player with no lines" do
    get player_url(@imazu)

    assert_select "h2", text: "打撃成績", count: 0
    assert_select "h2", text: "投手成績", count: 0
    assert_select "details.decade", 0
  end
end
