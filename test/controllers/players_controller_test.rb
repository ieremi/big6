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

    assert_select "th[title=?] button", "出塁率＋長打率", text: /OPS/
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

  # ---- sorting the table by any column

  def sorted_names(sort, direction = nil)
    get players_url, params: { sort: sort, direction: direction }.compact
    assert_response :success
    listed_names
  end

  # Every player with a reading, so the order by name doesn't depend on how the
  # database compares kanji.
  def give_readings
    @old.update!(name_kana: "ヤマダ タロウ")
    @coach.update!(name_kana: "ヒノ アイロウ")
  end

  test "index sorts by the reading of the name" do
    give_readings

    assert_equal [ "今津 慶介", "落合 智哉", "日野 愛郎", "山田 太郎" ], sorted_names("name", "asc")
    assert_equal [ "山田 太郎", "日野 愛郎", "落合 智哉", "今津 慶介" ], sorted_names("name", "desc")
  end

  test "index sorts by entry year, with those without one last either way, equal years in the usual order" do
    assert_equal [ "山田 太郎", "落合 智哉", "今津 慶介", "日野 愛郎" ], sorted_names("enter_year", "asc")
    assert_equal [ "落合 智哉", "今津 慶介", "山田 太郎", "日野 愛郎" ], sorted_names("enter_year", "desc")
  end

  test "index sorts by university in the league's order" do
    assert_equal [ "落合 智哉", "山田 太郎", "日野 愛郎", "今津 慶介" ], sorted_names("university", "asc")
    assert_equal [ "今津 慶介", "落合 智哉", "山田 太郎", "日野 愛郎" ], sorted_names("university", "desc")
  end

  test "index sorts positions in fielding order, not alphabetically, with blanks last" do
    assert_equal [ "落合 智哉", "今津 慶介", "山田 太郎", "日野 愛郎" ], sorted_names("position", "asc") # 捕手, 遊撃手
    assert_equal [ "今津 慶介", "落合 智哉", "山田 太郎", "日野 愛郎" ], sorted_names("position", "desc")
  end

  test "index sorts roles with players before staff" do
    assert_equal [ "落合 智哉", "今津 慶介", "山田 太郎", "日野 愛郎" ], sorted_names("role", "asc")
    assert_equal [ "日野 愛郎", "落合 智哉", "今津 慶介", "山田 太郎" ], sorted_names("role", "desc")
  end

  test "index sorts by status and by hands, and leaves blank high schools and hands last" do
    @ochiai.update!(pitching_hand: "左", batting_hand: "右")
    @imazu.update!(pitching_hand: "右", batting_hand: "右")

    assert_equal [ "落合 智哉", "今津 慶介", "山田 太郎", "日野 愛郎" ], sorted_names("status", "asc")
    assert_equal [ "日野 愛郎", "山田 太郎", "落合 智哉", "今津 慶介" ], sorted_names("status", "desc")
    assert_equal [ "今津 慶介", "落合 智哉", "山田 太郎", "日野 愛郎" ], sorted_names("hands", "asc")
    assert_equal [ "落合 智哉", "今津 慶介", "山田 太郎", "日野 愛郎" ], sorted_names("hands", "desc")
    assert_equal "日野 愛郎", sorted_names("high_school", "asc").last
    assert_equal "日野 愛郎", sorted_names("high_school", "desc").last
  end

  test "index ignores a sort it does not know, and a direction without a sort" do
    default = [ "落合 智哉", "今津 慶介", "山田 太郎", "日野 愛郎" ]

    assert_equal default, sorted_names("bogus", "desc")
    get players_url, params: { direction: "desc" }
    assert_equal default, listed_names
  end

  test "index headings are sort links with a capital-letter shortcut each" do
    get players_url, params: { q: "落合" }

    { "university" => "U", "name" => "N", "enter_year" => "Y", "role" => "O", "position" => "P",
      "hands" => "B", "high_school" => "S", "status" => "E" }.each do |key, shortcut|
      assert_select "th.sortable a[data-shortcut=?][href*=?]", shortcut, "sort=#{key}"
    end
    assert_select "th.sortable a[href*=?]", "q=", 8 # the search is kept
  end

  test "index shows entry year, newest first, as sorted when nothing is asked for, and a second click reverses" do
    get players_url

    assert_select "th.sortable.sorted-desc a[data-shortcut=Y][href*=?]", "direction=asc"
    assert_select "th.sortable.sorted-desc, th.sortable.sorted-asc", 1

    get players_url, params: { sort: "name", direction: "asc" }

    assert_select "th.sortable.sorted-asc a[data-shortcut=N][href*=?]", "direction=desc"
    assert_select "th[aria-sort=ascending]", 1
    assert_select "th.sortable.sorted-desc", 0
  end

  test "index paging keeps the sort" do
    50.times { |i| create_player(30000000 + i, @beta, "選手#{i}", name_kana: "センシュ#{i.to_s.rjust(2, '0')}", enter_year: 2020) }

    get players_url, params: { sort: "name", direction: "desc" }

    assert_select "nav.pagination a[rel=next][href*=?]", "sort=name"
    assert_select "nav.pagination a[rel=next][href*=?]", "direction=desc"
  end

  # ---- the player page's tables are sorted in the browser

  def stats_for_ochiai
    game = games(:one)
    other = Game.create!(season: seasons(:two), team0: @alpha, team1: @beta, played_on: "2026-09-12", game_number: 1)
    BattingLine.create!(game: game, player: @ochiai, university: @alpha, pa: 5, ab: 4, hits: 2, walks: 1)
    BattingLine.create!(game: other, player: @ochiai, university: @alpha, pa: 4, ab: 4, hits: 1)
    PitchingLine.create!(game: game, player: @ochiai, university: @alpha, outs: 10, earned_runs: 3, wins: 1, started: 1)
    PitchingLine.create!(game: other, player: @ochiai, university: @alpha, outs: 4, earned_runs: 0, losses: 1)
    GameMember.create!(game: game, player: @ochiai, university: @alpha, uniform_number: 27, grade: 3, role: "捕手", batting_order: 5, fielding_position: "捕")
  end

  test "show puts every table in a sortable-table, each with sort buttons and shortcut keys" do
    stats_for_ochiai

    get player_url(@ochiai)

    assert_select "table[data-controller=sortable-table]", 5 # batting and pitching seasons, both game tables, the bench
    assert_select "table[data-controller=sortable-table] th.sortable button[data-action=?]", "sortable-table#sort", minimum: 40
    assert_select "th.sortable button[data-shortcut][data-shortcut-all]", minimum: 40
  end

  test "show gives batting capital shortcuts and pitching lower-case ones" do
    stats_for_ochiai

    get player_url(@ochiai)

    shortcuts = ->(labels) { labels.map { |label| css_select("th.sortable button").find { |button| button.text.strip.start_with?("#{label} ") }["data-shortcut"] } }
    assert_equal %w[A O P H M], shortcuts.call(%w[打率 OPS 打席 安打 本塁打])
    assert_equal %w[e w l i k], shortcuts.call(%w[防御率 勝 敗 投球回 奪三振])
  end

  test "show shares a shortcut between the tables that have the column, and never uses one twice for different columns" do
    stats_for_ochiai

    get player_url(@ochiai)

    by_shortcut = css_select("th.sortable button[data-shortcut]").group_by { |button| button["data-shortcut"] }
    # D is the date or season of every table, V the opponent or game
    assert_equal 5, by_shortcut.fetch("D").size
    assert_equal 3, by_shortcut.fetch("V").size # both game tables and the bench
    # the batting season and game tables both have 安打, and so on: two of each
    assert_equal 2, by_shortcut.fetch("H").size
    # otherwise one key is one column, told by its heading
    by_shortcut.except("D", "V").each do |key, buttons|
      assert_equal 1, buttons.map { |button| button.text.strip.delete_suffix(" #{key}") }.uniq.size, "#{key} is used for different columns: #{buttons.map(&:text)}"
    end
  end

  test "show does not take a key that the page or the site already uses" do
    stats_for_ochiai

    get player_url(@ochiai)

    sort_keys = css_select("th.sortable button[data-shortcut]").map { |button| button["data-shortcut"] }.uniq
    other_keys = css_select("[data-shortcut]").reject { |el| el.name == "button" && el["class"].to_s.include?("sort-button") }.map { |el| el["data-shortcut"] }
    assert_empty sort_keys & other_keys # 0-8, -, u and f
  end

  test "show keeps the totals row fixed and gives cells their sort values" do
    stats_for_ochiai

    get player_url(@ochiai)

    assert_select "tr.stats-total[data-sort-fixed]", 2
    assert_select "table td[data-sort-value=?]", "2026" # the spring season sorts by year
    assert_select "table td[data-sort-value=?]", "2026.5" # and the autumn one half a year later
    assert_select "table td[data-sort-value=?]", "10" # innings 3 1/3, as outs
    assert_select "td[data-sort-value=?]", "0.5", text: ".500" # the batting average sorts as a number, not as ".500"
  end

  test "show gives the bench table the same date shortcut and its own for the other columns" do
    stats_for_ochiai

    get player_url(@ochiai)

    { "日付" => "D", "試合" => "V", "背番号" => "U", "学年" => "Y", "役割" => "T", "打順" => "Q", "守備" => "Z" }.each do |label, shortcut|
      assert_select "table:last-of-type th.sortable button[data-shortcut=?]", shortcut, text: /\A#{label} /
    end
  end

  test "no two elements on the players page share a shortcut key, the headings' keys included" do
    University.create!(name: "Rikkio University", short_name: "Rikkio", slug: "rikkio", position: 4)

    get players_url

    keys = css_select("[data-shortcut]").map { |element| element["data-shortcut"] }
    assert_operator keys.size, :>, 10
    assert_equal [], keys.tally.select { |_, count| count > 1 }.keys
  end
end
