require "test_helper"

class ArticlesControllerTest < ActionDispatch::IntegrationTest
  # The six universities, which the 2027 spring prediction names by slug.
  def create_the_six
    { "waseda" => "早大", "keio" => "慶大", "meiji" => "明大", "hosei" => "法大", "rikkio" => "立大", "tokyo" => "東大" }.each_with_index do |(slug, short), i|
      University.create!(name: short, short_name: short, slug:, position: 10 + i)
    end
  end

  test "the 早慶戦 article counts who stood lower going in and whether that side took the card" do
    create_the_six
    by = University.all.index_by(&:slug)
    season = Season.find_or_create_by!(year: 2025, term: "spring")
    game = lambda do |day, winner, loser, number|
      Game.create!(season:, team0: by[winner], team1: by[loser], played_on: Date.new(2025, 5, day), game_number: number,
        team0_score: 3, team1_score: 1, game_status: "試合終了")
    end
    # Before the 早慶戦: 早大 takes a card from 明大, 慶大 loses one to 法大, so 慶大 stands lower.
    game.(3, "waseda", "meiji", 1); game.(4, "waseda", "meiji", 2)
    game.(3, "hosei", "keio", 1); game.(4, "hosei", "keio", 2)
    # 法大–明大 the same days, then the 早慶戦, which 慶大 takes.
    game.(10, "hosei", "meiji", 1); game.(11, "meiji", "hosei", 2); game.(12, "hosei", "meiji", 3)
    game.(31, "keio", "waseda", 1); game.(31, "keio", "waseda", 2)

    # Its first URL is sent on to this one.
    get article_path("sokei-underdog")
    assert_redirected_to article_path("sokei-standings")

    get article_path("sokei-standings")

    assert_response :success
    assert_select "table.sokei-standings tbody tr:first-child td:first-of-type", text: "100%（1/1）"
    assert_select "table.sokei-standings tbody tr:first-child td:last-of-type", text: "0%（0/1）" # 法大–明大: 明大 stood lower, 法大 took it
    assert_select "td", text: "下の方が勝った"
    # Had 早大 taken the 早慶戦, it would have been top (勝ち点2 like 法大, 4勝0敗 to 4勝1敗); 法大 won it instead.
    assert_select "table.sokei-lost-titles tbody tr", 1 do
      assert_select "td .team-chip[title=?]", "早大"
      assert_select "td .team-chip[title=?]", "法大"
    end
  end

  test "the articles are listed, and each has its own page" do
    get articles_path

    assert_response :success
    assert_select "h1", "読み物"
    assert_select ".news-list a[href=?]", article_path("draft-2026"), text: "2026年ドラフト会議と東京六大学"
  end

  test "the draft article lists who filed and who was picked, with the titles won while they were there" do
    alpha, beta = universities(:one), universities(:two)
    star = Player.create!(scorebook_id: 20231001, university: alpha, name: "一番 星", enter_year: 2023, position: "投手")
    Player.create!(scorebook_id: 20231002, university: alpha, name: "育成 枠", enter_year: 2023, position: "捕手")
    Player.create!(scorebook_id: 20236001, university: beta, name: "二番 手", enter_year: 2023, position: "内野手")

    stub_method(DraftEntrants, :path, ->(_year) { file_fixture("draft_test.yml") }) { get article_path("draft-2026") }

    assert_response :success
    assert_select "h1", "2026年ドラフト会議と東京六大学"
    assert_select "article p", text: /東京六大学からは2人が指名されました（本指名1人、育成1人）。\s*プロ野球志望届を出したのは2大学の3人/
    assert_select "article p", text: /育成選手選択会議では、Alphaの育成 枠（読売ジャイアンツ・育成2位）が指名されました/
    assert_select "article p", text: /1位指名はAlphaの一番 星（阪神タイガース）/
    assert_select "table tbody tr td a[href=?]", player_path(star.scorebook_id), text: "一番 星"
    picked_table = css_select("table").find { |table| table.css("th").map(&:text) == %w[選手 大学 守備 球団 順位 打率 防御率] }
    assert picked_table, "the picks' table has the columns 選手 大学 守備 球団 順位 打率 防御率"
    assert_equal [ "一番 星", "Alpha", "投手", "阪神タイガース", "1位", "---", "---" ], picked_table.css("tbody tr").first.css("td").map { |td| td.text.strip } # no lines yet
    assert_select "table tbody tr td", "読売ジャイアンツ 育成2位"
    assert_select "a[href=?][target=_blank]", "https://npb.jp/draft/2026/"

    # The filers' table sorts in the browser, its dates as 2026-09-05.
    assert_select "table[data-controller=sortable-table] th.sortable button[data-action=?]", "sortable-table#sort", 8
    assert_select "table[data-controller=sortable-table] tbody td", "2026-10-02"
    assert_select "table[data-controller=sortable-table] tbody td[data-sort-value=?]", "", text: "—" # not picked: last whichever way
  end

  test "the strength spread article names the seasons furthest and closest apart, and lists them all" do
    alpha, beta = universities(:one), universities(:two)
    row = ->(year, variance, without) do
      StrengthSpread::Row.new(season: Season.find_or_create_by!(year: year, term: "spring"), variance: variance, variance_without_tokyo: without,
        chances: { alpha => 0.7, beta => 0.3 })
    end
    rows = [ row.(2001, 0.9, 0.2), row.(2002, 0.4, 0.01), row.(2003, 0.6, 0.5) ]

    stub_method(StrengthSpread, :rows, -> { rows }) { get article_path("strength-spread") }

    assert_response :success
    assert_select "article p", text: /もっとも離れていたのは\s*2001年春季\s*、もっとも近かったのは\s*2002年春季\s*でした/
    assert_select "article p", text: /東大を除いた5大学でもっとも近かったのは\s*2002年春季\s*、\s*もっとも離れていたのは\s*2003年春季/
    assert_select "table[data-controller=sortable-table] tbody tr", 3
    assert_select "table tbody td", text: "Alpha70 Beta30", minimum: 1
    assert_select "a[href=?]", strength_seasons_path
  end

  test "the postwar article charts the strengths season by season, with the averages by decade and each one's best and worst" do
    alpha, beta = universities(:one), universities(:two)
    row = ->(year, term, chance) do
      StrengthSpread::Row.new(season: Season.find_or_create_by!(year: year, term: term), variance: 0.5, variance_without_tokyo: 0.1,
        chances: { alpha => chance, beta => 1 - chance })
    end
    rows = [ row.(1938, "autumn", 0.9), row.(2010, "spring", 0.6), row.(2010, "autumn", 0.3), row.(2021, "spring", 0.8) ]

    stub_method(StrengthSpread, :rows, -> { rows }) { get article_path("strength-postwar") }

    assert_response :success
    assert_select "[data-view=chance]:not([hidden]) figure.line-chart svg polyline.line-chart-line", 2
    # One view-switch over the article, so the buttons also switch the figures in the tables.
    assert_select "article[data-controller=view-switch]", 1
    assert_select "[data-controller=view-switch]", 1
    assert_select "article button.period-btn", %w[確率 オッズ 対数オッズ].size
    assert_select "[data-view=odds][hidden] figure[data-line-chart-kind-value=odds]"
    assert_select "[data-view=chance] .line-chart-table tbody tr", 3 # 1938 is before the war
    assert_select "[data-view=chance] svg text.line-chart-axis-label", text: "2010"
    assert_select "table.formula-table tbody th", %w[2010年代 2020年代].size
    assert_select "table tbody tr td", text: /2021年春季（80%/ # alpha's best
    assert_select "table tbody tr td", text: /2010年秋季（30%/ # alpha's worst
    assert_select "table tbody tr td span[data-view=odds][hidden]", text: "4.00" # alpha's best as odds
  end

  test "the Jingu article tallies the league's entrants, and lists every tournament" do
    %w[waseda keio meiji hosei rikkio tokyo].each_with_index do |slug, i|
      University.find_or_create_by!(slug:) { |university| university.assign_attributes(name: slug, short_name: slug, position: 10 + i) }
    end

    get article_path("jingu-big6-record")

    assert_response :success
    assert_select ".article-lead", text: /16回優勝/
    assert_select "h2", text: "すべての大会"
    assert_select "td", text: "第57回"
  end

  test "the home runs article gives the fewest, the most, the mean and the spread, and every season" do
    Game.delete_all
    player = Player.create!(scorebook_id: 1, university: universities(:one), name: "打者", enter_year: 2023, role: "選手")
    { 2001 => 3, 2002 => 5 }.each do |year, count|
      season = Season.create!(year: year, term: "spring")
      game = Game.create!(season:, team0: universities(:one), team1: universities(:two), played_on: Date.new(year, 4, 1), game_number: 1,
        team0_score: 3, team1_score: 1, game_status: "試合終了")
      BattingLine.create!(game:, player:, university: universities(:one), ab: 4, hits: count, home_runs: count)
    end

    get article_path("home-runs-per-season")

    assert_response :success
    assert_select "article p", text: /平均\s*4.0本\s*（標準偏差1.0本）/
    assert_select "article p", text: /2002年春季の5本/
    assert_select "table[data-controller=sortable-table] tbody tr", 2
    assert_select "tr:not(.muted) td", text: "2／2" # the 2000s: both seasons counted
    assert_select "h2", text: /今季/, count: 0

    today = ActiveSupport::TimeZone["Asia/Tokyo"].today
    on = Season.create!(year: today.year + 1, term: "spring")
    [ today - 1, today + 1 ].each_with_index do |day, i|
      game = Game.create!(season: on, team0: universities(:one), team1: universities(:two), played_on: day, game_number: i + 1,
        team0_score: (3 if i.zero?), team1_score: (1 if i.zero?), game_status: i.zero? ? "試合終了" : "試合前")
      BattingLine.create!(game:, player:, university: universities(:one), ab: 4, hits: 2, home_runs: 2) if i.zero?
    end

    get article_path("home-runs-per-season")

    assert_select "h2", text: "今季（#{on.title}、途中）"
    assert_select "article p", text: /ここまで1試合で\s*2本\s*、1試合あたり\s*2.00本.*全2試合を終えると、約4本/m
  end

  test "the fifty years article's old URL is sent on to the postwar one" do
    get article_path("strength-50-years")

    assert_redirected_to article_path("strength-postwar")
    assert_response :moved_permanently
  end

  test "the freshman batting champions article lists them, how many won it in each year, and the 1年生 leading now" do
    Player.create!(scorebook_id: 2, university: universities(:two), name: "一年秋", enter_year: 2024, role: "選手", high_school: "花巻東")
    game = Game.where(season: seasons(:one)).order(:played_on).first
    rookie = Player.create!(scorebook_id: 4, university: game.team0, name: "新人", enter_year: 2026, role: "選手")
    BattingLine.create!(game:, player: rookie, university: game.team0, pa: 4, ab: 4, hits: 3)

    stub_method(LeadingHitters, :path, -> { file_fixture("leading_hitters_test.yml") }) { get article_path("freshman-leading-hitters") }

    assert_response :success
    assert_select "table[data-controller=sortable-table] tbody tr", 1
    assert_select "table tbody td a[href=?]", player_path(2), text: "一年秋"
    assert_select "table tbody td", text: "花巻東"
    assert_select "table.formula-table tbody tr", 5 # 1年生 to 4年生, and わからない
    assert_select "article p", text: /上位10位までにいる1年生は\s*新人（.+、1位、\.750）です。\s*このまま終われば/
    assert_select "article p.muted", text: /名鑑にない選手（名鑑外）/
  end

  test "the 越後 article says what each batter with games left needs to pass him" do
    Game.delete_all
    alpha, beta = universities(:one), universities(:two)
    season = Season.find_or_create_by!(year: 2026, term: "autumn")
    played = Game.create!(season:, team0: alpha, team1: beta, played_on: Date.new(2026, 10, 31), game_number: 1, team0_score: 3, team1_score: 1, game_status: "試合終了")
    Game.create!(season:, team0: beta, team1: alpha, played_on: Date.current + 3, game_number: 2, game_status: "試合前")
    echigo = Player.create!(scorebook_id: 20266006, university: alpha, name: "越後 駿祐", enter_year: 2026, role: "選手")
    rival = Player.create!(scorebook_id: 2, university: beta, name: "打者", enter_year: 2025, role: "選手")
    BattingLine.create!(game: played, player: echigo, university: alpha, pa: 4, ab: 4, hits: 2)
    BattingLine.create!(game: played, player: rival, university: beta, pa: 4, ab: 4, hits: 1)

    get article_path("echigo-batting-title")

    assert_response :success
    assert_select "article p", text: /越後 駿祐選手（.+、1年）は\s*1位、打率\.500/
    assert_select "article table tbody tr", 1
    assert_select "article table tbody td a[href=?]", player_path(rival), text: "打者"
  end

  test "the 2026 autumn highlights give three or four points for each university done, linking the players" do
    get article_path("autumn-2026-highlights")

    assert_response :success
    assert_select "article h2.card-heading", 4
    assert_select "article ul", 4
    assert_select "article li a[href=?]", player_path(20266006), text: "越後駿祐"
  end

  test "each article and the list have an OG image, which the page names" do
    get article_path("home-runs-per-season")
    assert_select "meta[property='og:image'][content=?]", article_og_image_url("home-runs-per-season")

    get article_og_image_path("home-runs-per-season")
    assert_response :success
    assert_equal "image/png", response.media_type

    get article_og_image_path("strength-50-years") # moved: the image of the article it moved to
    assert_response :success

    get articles_path
    assert_select "meta[property='og:image'][content=?]", articles_og_image_url
    get articles_og_image_path
    assert_equal "image/png", response.media_type
  end

  test "the seniors article shows each university's starters and bench as a band chart and a table" do
    game = Game.where(season: seasons(:one)).order(:played_on).first
    player = Player.create!(scorebook_id: 1, university: game.team0, name: "四年", enter_year: 2023, role: "選手", enrollment_status: Player::ACTIVE_ENROLLMENT_STATUS)
    GameMember.create!(game:, player:, university: game.team0, batting_order: 1, fielding_position: "中")

    get article_path("senior-appearances")

    assert_response :success
    assert_select ".band-chart .band-row", 2 # the university and 全体
    assert_select ".band-chart .band-started[style=?]", "width: 100.0%"
    assert_select "table.formula-table tbody tr", 2
    lead = css_select("p.article-lead").first.text.gsub(/\s+/, "")
    assert_operator lead.length, :<=, 140
    assert_match "1人のうち、リーグ戦で1回でもスタメンに入ったのは100%", lead
  end

  test "the 2027 spring schedule article gives the eight weeks, and the cards if 慶大 plays first instead" do
    create_the_six
    get article_path("schedule-2027-spring")

    assert_response :success
    assert_select "table.formula-table:not(.game-times) tbody tr", 8
    assert_select "table.formula-table tbody tr:first-child td", text: "明大–東大、早大–立大"
    assert_select "table.formula-table tbody tr:first-child td.muted", text: "明大–東大、慶大–立大"
    assert_select "table.game-times tbody tr:first-child td", text: "10:00 am〜12:30 pm" # プロ併用日
    assert_includes 135..140, css_select("p.article-lead").first.text.gsub(/\s+/, "").length
    assert_select "article h3.week-heading", 8
    assert_select "details.ics-preview-toggle[data-ics-preview-url-value=?]", article_path("schedule-2027-spring", format: :ics)
    assert_select "h3.week-heading .week-cards", text: "慶大–法大、早大–明大"
    assert_select "figure.week-diagram", 8
    # The weeks with days shared with the professionals say so: 第2・5・6週, and 第4週's 3回戦 day.
    assert_select "article p.muted", text: /\Aプロ併用日：/, count: 4
    assert_select "article p.muted", text: /プロ併用日：4月17日（土）・4月18日（日）。/
    assert_select "article p.muted", text: /プロ併用日：3回戦になれば5月3日（祝）。/
    assert_select "figure.week-diagram svg[aria-label=?] path", "第8週の組み合わせ：早大–慶大", 1
    assert_select "figure.week-diagram svg[aria-label=?] .week-diagram-idle", "第8週の組み合わせ：早大–慶大", 4
  end

  test "the 明治神宮野球大会 article gives every game day by day, with 明治大's first, and calendars of either division" do
    get article_path("jingu-tournament-2026")

    assert_response :success
    assert_select "table.jingu-games tbody tr", 19
    assert_select "table.jingu-games tr.highlight td", text: /明治大 vs 未定/
    assert_select "table.jingu-games td", text: "1:30 pm"
    assert_match "11月21日（土）の第3試合（1:30 pm）", css_select("p.article-lead").first.text

    get article_path("jingu-tournament-2026", format: :ics)
    assert_equal 19, response.body.scan("BEGIN:VEVENT").size
    assert_match(/DTSTART;TZID=Asia\/Tokyo:20261121T133000\r\n.*?SUMMARY:【神宮大会・大学】明治大 vs 未定（2回戦）/m, response.body)
    # Two and a half hours, but no later than the next game: 8:30 am then 11:00 am.
    assert_match(/DTSTART;TZID=Asia\/Tokyo:20261119T083000\r\nDTEND;TZID=Asia\/Tokyo:20261119T110000/, response.body)

    # If 明治大 wins it: three games, and the bracket with its way drawn in.
    get article_path("jingu-tournament-2026")
    assert_select "table.meiji-path tbody tr", 3
    assert_select "table.meiji-path tbody tr:first-child td", text: "筑波大・中京大のどちらか"
    assert_select "figure.jingu-bracket svg text", text: "日本体育大"
    assert_select "figure.jingu-bracket line.jingu-bracket-path", 7 # 明治大 to 2回戦, on to 準決勝 and 決勝 (two each), and 優勝

    get article_path("jingu-tournament-2026", format: :ics, division: "meiji")
    assert_equal 3, response.body.scan("BEGIN:VEVENT").size

    get article_path("jingu-tournament-2026", format: :ics, division: "college")
    assert_equal 10, response.body.scan("BEGIN:VEVENT").size # 11 universities
    assert_no_match "高校", response.body.split("BEGIN:VEVENT", 2).last
  end

  test "the 2027 spring schedule comes as a calendar, 慶大 first on asking, and other articles have none" do
    create_the_six
    get article_path("schedule-2027-spring", format: :ics)

    assert_response :success
    assert_equal "text/calendar", response.media_type
    assert_equal 30, response.body.scan("BEGIN:VEVENT").size # 15 cards, a Saturday and a Sunday game each
    assert_includes response.body, "DTSTART;TZID=Asia/Tokyo:20270410T110000" # 明大–東大, the week's first card
    assert_includes response.body, "DTSTART;TZID=Asia/Tokyo:20270410T140000" # 早大–立大, the second
    # On Sunday the other way round, each card's sides swapped: 立大–早大 first, then 東大–明大.
    assert_match(/DTSTART;TZID=Asia\/Tokyo:20270411T110000\r\n.*?SUMMARY:【予想】立大 vs 早大②/m, response.body)
    assert_match(/DTSTART;TZID=Asia\/Tokyo:20270411T140000\r\n.*?SUMMARY:【予想】東大 vs 明大②/m, response.body)
    # A プロ併用日 (4月17日, ヤクルト at home at 神宮) is an hour earlier: 10:00 and 13:00.
    assert_includes response.body, "DTSTART;TZID=Asia/Tokyo:20270417T100000"
    assert_includes response.body, "DTSTART;TZID=Asia/Tokyo:20270417T130000"
    assert_not_includes response.body, "DTSTART;TZID=Asia/Tokyo:20270417T110000"
    assert_includes response.body, "DTSTART;TZID=Asia/Tokyo:20270529T130000" # the 早慶戦, at 1:00 pm
    assert_includes response.body, "SUMMARY:【予想】早大 vs 立大①"

    get article_path("schedule-2027-spring", format: :ics, first: "keio")
    assert_includes response.body, "SUMMARY:【予想】慶大 vs 立大①"

    get article_path("home-runs-per-season", format: :ics)
    assert_response :not_found
  end

  test "the 小宮山 article gives 早大's record against each university since 2019 and the players drafted" do
    create_the_six
    waseda, keio = University.find_by(slug: "waseda"), University.find_by(slug: "keio")
    season = Season.find_or_create_by!(year: 2019, term: "spring")
    Game.create!(season:, team0: waseda, team1: keio, played_on: Date.new(2019, 6, 1), game_number: 1, team0_score: 4, team1_score: 2, game_status: "試合終了")

    get article_path("komiyama-record")

    assert_response :success
    assert_select "p.article-lead", text: /1勝0敗0分/
    assert_select "table.formula-table tbody tr th a", text: "慶大"
    assert_select "table.formula-table tbody td a[href=?]", player_path(20171019), text: "早川隆久"
    assert_select "table.formula-table tbody tr th", text: "2019年"
  end

  test "the site's changes this autumn give a game only when one was being played at the time" do
    season = Season.find_or_create_by!(year: 2026, term: "autumn")
    Game.create!(season:, team0: universities(:one), team1: universities(:two), played_on: Date.new(2026, 9, 13), game_number: 2,
      team0_score: 3, team1_score: 1, game_status: "試合終了",
      source_scoreboard: { "gameStartActual" => "11時00分", "gameFinishTime" => "13時10分" })

    get article_path("site-changes-2026-autumn")

    assert_response :success
    rows = css_select("table.site-changes tbody tr")
    assert_equal 54, rows.size
    assert_equal "Alpha–Beta 2回戦", rows[0].css("td")[1].text.strip # 9月13日 11:47, during the game
    assert_equal "", rows[1].css("td")[1].text.strip # 13:23, after it
  end

  test "an article that isn't there is not found" do
    get article_path("no-such-article")

    assert_response :not_found
  end
end
