require "test_helper"

class RankingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @alpha = universities(:one)
    @beta = universities(:two)
    @spring = seasons(:one)
    @autumn = seasons(:two)
    @next_id = 50_000_000
  end

  def player(name, university: @alpha)
    Player.create!(scorebook_id: @next_id += 1, university: university, name: name, enter_year: 2023)
  end

  def game(season, number)
    Game.create!(season: season, team0: @alpha, team1: @beta, played_on: Date.new(2026, 1, 1) + number, game_number: number)
  end

  def bat(player, game, **stats)
    BattingLine.create!({ game: game, player: player, university: player.university, pa: 30, ab: 27, hits: 9, walks: 3, total_bases: 12 }.merge(stats))
  end

  def pitch(player, game, **stats)
    PitchingLine.create!({ game: game, player: player, university: player.university, outs: 45, earned_runs: 5 }.merge(stats))
  end

  def ranked_names
    css_select("tbody tr td:nth-child(2) a").map(&:text)
  end

  test "the OPS ranking is the default and lists batters best first with their rank" do
    bat(player("低い"), game(@spring, 1), hits: 5, total_bases: 6)
    bat(player("高い"), game(@spring, 2), hits: 12, total_bases: 24)

    get rankings_url, params: { season: "2026-spring" }

    assert_response :success
    assert_select "h1", "打者ランキング"
    assert_select "title", /打者ランキング（2026年春季） - Big6/
    assert_equal %w[高い 低い], ranked_names
    assert_select "tbody tr:first-child td:first-child", "1"
    assert_select "thead th", text: "OPS"
  end

  test "the ERA ranking lists pitchers lowest first" do
    pitch(player("打たれた"), game(@spring, 1), earned_runs: 20)
    pitch(player("好投"), game(@spring, 2), earned_runs: 2)

    get ranking_url("pitching"), params: { season: "2026-spring" }

    assert_response :success
    assert_select "title", /投手ランキング（2026年春季） - Big6/
    assert_select "h1", "投手ランキング"
    assert_equal %w[好投 打たれた], ranked_names
    assert_select "thead th", text: "防御率"
    assert_select "tbody tr:first-child td", text: "1.20" # 2 earned runs in 15 innings (45 outs)
  end

  test "without a season the ranking is over the whole career, from a minimum of 40 plate appearances" do
    over = player("通算")
    bat(over, game(@spring, 1), pa: 25)
    bat(over, game(@autumn, 2), pa: 15)
    bat(player("通算39"), game(@spring, 3), pa: 39)

    get rankings_url

    assert_select "title", /（通算）/
    assert_equal %w[通算], ranked_names
    assert_select "p.muted", text: /通算で40打席以上の打者が対象です/
    assert_select "meta[name=description][content=?]", "東京六大学野球の打者ランキング（通算、40打席以上の打者）"
  end

  test "a season's minimum is 10 plate appearances" do
    bat(player("十"), game(@spring, 1), pa: 10)
    bat(player("九"), game(@spring, 2), pa: 9)

    get rankings_url, params: { season: "2026-spring" }

    assert_equal %w[十], ranked_names
    assert_select "p.muted", text: /シーズンで10打席以上の打者が対象です/
    assert_select "p.muted", text: /優勝決定戦は含みません/
    assert_select "p.muted", text: /出塁率は犠飛を含めない簡易式/
  end

  test "the ERA page counts its minimum in innings: 40 for a career, 10 for a season" do
    pitch(player("投手"), game(@spring, 1))

    get ranking_url("pitching")

    assert_select "p.muted", text: /通算で40投球回以上の投手が対象です/
    assert_select "fieldset legend", text: "最低投球回数"
    assert_select "input#minimum[value=?]", "40"

    get ranking_url("pitching"), params: { season: "2026-spring" }

    assert_select "p.muted", text: /シーズンで10投球回以上の投手が対象です/
    assert_select "input#minimum[value=?]", "10"
  end

  # ---- asking for another minimum

  test "the form has a field holding the minimum, so that the arrows step from it, and the default it is beside" do
    bat(player("選手"), game(@spring, 1), pa: 100)

    get rankings_url

    assert_select "fieldset legend", text: "最低打席数"
    assert_select "input#minimum[type=number][min='0'][value=?]", "40" # 40 to 41, not 0 to 1
    assert_select "input#default_minimum[type=hidden][value=?]", "40"
    assert_select "form .muted", text: "（既定）"
    assert_select "a", text: /既定.*に戻す/, count: 0
  end

  test "a minimum in the URL is applied, and shown in the field with a way back to the default" do
    bat(player("二十"), game(@spring, 1), pa: 20)
    bat(player("五十"), game(@spring, 2), pa: 50)

    get rankings_url, params: { minimum: 15 }

    assert_equal %w[二十 五十].sort, ranked_names.sort
    assert_select "p.muted", text: /通算で15打席以上の打者が対象です/
    assert_select "input#minimum[value=?]", "15"
    assert_select "a[href=?]", ranking_path("batting"), text: "既定（40打席）に戻す"

    get rankings_url, params: { minimum: 30 }

    assert_equal %w[五十], ranked_names
  end

  test "a minimum of 0 ranks everyone, and the page says why the few-at-bat players are on top" do
    bat(player("一打席"), game(@spring, 1), pa: 1, ab: 1, hits: 1, total_bases: 4)

    get rankings_url, params: { minimum: 0 }

    assert_equal %w[一打席], ranked_names
    assert_select "p.muted", text: /通算で打席のある打者すべてが対象です/
    assert_select "p.muted", text: /最低数がないため、打席の少ない選手が上位に並びます/
    assert_select "input#minimum[value=?]", "0"
  end

  test "a minimum that is not a whole number is the default" do
    bat(player("選手"), game(@spring, 1), pa: 100)

    [ "", "abc", "-5", "2.5" ].each do |value|
      get rankings_url, params: { minimum: value }

      assert_equal %w[選手], ranked_names, value.inspect
      assert_select "p.muted", text: /通算で40打席以上の打者が対象です/
    end
  end

  test "the minimum is kept by the sort links, the paging and the season selector's form, but not by the other kind's tab" do
    bat(player("選手"), game(@spring, 1), pa: 100)

    get rankings_url, params: { minimum: 15, university_ids: [ @alpha.id ] }

    assert_select "thead th a[href*=?]", "minimum=15", minimum: 12
    assert_select "input#minimum[value=?]", "15" # the form sends it again with the other filters
    assert_select ".period-toolbar a.period-btn[href^=?]", ranking_path("pitching"), text: "投手"
    assert_select ".period-toolbar a.period-btn[href*=?]", "minimum", count: 0 # neither the minimum nor its default
  end

  test "a minimum the form sends unchanged, beside its default, is not asked for: the period's default follows" do
    bat(player("十五"), game(@spring, 1), pa: 15)
    bat(player("五"), game(@spring, 2), pa: 5)

    get rankings_url, params: { season: "2026-spring", minimum: 40, default_minimum: 40 } # left a career for a season

    assert_equal %w[十五], ranked_names
    assert_select "input#minimum[value=?]", "10"
    assert_select "input#default_minimum[value=?]", "10"
    assert_select "form .muted", text: "（既定）"
  end

  test "a minimum that was changed is kept when the period changes" do
    bat(player("十五"), game(@spring, 1), pa: 15)
    bat(player("二十五"), game(@spring, 2), pa: 25)

    get rankings_url, params: { season: "2026-spring", minimum: 20, default_minimum: 40 }

    assert_equal %w[二十五], ranked_names
    assert_select "input#minimum[value=?]", "20"
    assert_select "a[href=?]", ranking_path("batting", season: "2026-spring"), text: "既定（10打席）に戻す"
  end

  test "a minimum with no default beside it (a link someone shared) is what was asked for, even if it is the default" do
    bat(player("十五"), game(@spring, 1), pa: 15)
    bat(player("五十"), game(@spring, 2), pa: 50)

    get rankings_url, params: { season: "2026-spring", minimum: 40 }

    assert_equal %w[五十], ranked_names
    assert_select "input#minimum[value=?]", "40"
  end

  test "an empty field is the default, and so is one that is not a number" do
    bat(player("十五"), game(@spring, 1), pa: 15)

    get rankings_url, params: { season: "2026-spring", minimum: "", default_minimum: 40 }
    assert_equal %w[十五], ranked_names

    get rankings_url, params: { season: "2026-spring", minimum: "abc" }
    assert_equal %w[十五], ranked_names
  end

  test "the season selector offers the seasons that have stats, newest first, with the chosen one selected" do
    bat(player("春"), game(@spring, 1))
    bat(player("秋"), game(@autumn, 2))

    get rankings_url, params: { season: "2026-autumn" }

    assert_equal [ "通算", "2026年秋季", "2026年春季" ], css_select("select#season option").map(&:text)
    assert_select "select#season option[selected]", text: "2026年秋季"
  end

  test "an unknown season falls back to the career" do
    get rankings_url, params: { season: "1900-spring" }

    assert_response :success
    assert_select "title", /（通算）/
  end

  test "an unknown kind is not a route" do
    get "/rankings/avg"

    assert_response :not_found
  end

  test "the kind tabs link to each other and mark the current one" do
    get rankings_url

    assert_select ".period-toolbar a.period-btn.active", text: "打者"
    assert_select ".period-toolbar a.period-btn[href^=?]", ranking_path("pitching"), text: "投手"
  end

  test "the university checkboxes limit the ranking" do
    bat(player("アルファ", university: @alpha), game(@spring, 1))
    bat(player("ベータ", university: @beta), game(@spring, 2))

    get rankings_url, params: { season: "2026-spring", university_ids: [ @beta.id ] }

    assert_equal %w[ベータ], ranked_names
    assert_select "input[name='university_ids[]'][checked][value=?]", @beta.id.to_s
  end

  test "players link to their pages and show their university" do
    bat(chosen = player("選手"), game(@spring, 1))

    get rankings_url, params: { season: "2026-spring" }

    assert_select "tbody a[href=?]", player_path(chosen), text: "選手"
    assert_select "tbody .team-chip", text: @alpha.initial
  end

  test "equal values share a rank on the page" do
    bat(player("同じ一"), game(@spring, 1))
    bat(player("同じ二"), game(@spring, 2))
    bat(player("下"), game(@spring, 3), hits: 1, total_bases: 1)

    get rankings_url, params: { season: "2026-spring" }

    assert_equal %w[1 1 3], css_select("tbody tr td:first-child").map(&:text)
  end

  test "the ranking pages through 50 at a time" do
    (1..51).each { |i| bat(player("選手#{i.to_s.rjust(2, '0')}"), game(@spring, i), total_bases: 12 + i) }

    get rankings_url, params: { season: "2026-spring" }
    assert_equal RankingsController::PER_PAGE, ranked_names.size
    assert_select "nav.pagination a[rel=next]"

    get rankings_url, params: { season: "2026-spring", page: 2 }
    assert_equal 1, ranked_names.size
    assert_select "nav.pagination a[rel=prev][href*=?]", "season=2026-spring"

    get rankings_url, params: { season: "2026-spring", page: 99 }
    assert_equal 1, ranked_names.size
  end

  test "an empty ranking says so" do
    get rankings_url, params: { season: "2026-spring" }

    assert_select "p", text: "条件に合う選手はいません。"
  end

  test "the sitemap lists the rankings" do
    get sitemap_url(format: :xml)

    assert_includes response.body, rankings_url
    assert_includes response.body, ranking_url("pitching")
  end

  # ---- sorting

  def add_batters_of_different_size
    bat(player("一位"), game(@spring, 1), pa: 30, ab: 27, hits: 15, walks: 3, total_bases: 30)   # best OPS, fewest PA
    bat(player("二位"), game(@spring, 2), pa: 45, ab: 40, hits: 14, walks: 5, total_bases: 20)
    bat(player("三位"), game(@spring, 3), pa: 60, ab: 54, hits: 10, walks: 6, total_bases: 14)   # most PA, lowest OPS
  end

  test "clicking a column sorts the whole table by it and numbers the rows again in that order" do
    add_batters_of_different_size

    get rankings_url, params: { season: "2026-spring", sort: "pa", direction: "desc" }

    assert_equal %w[三位 二位 一位], ranked_names
    assert_equal %w[1 2 3], css_select("tbody tr td:first-child").map(&:text) # numbered again in the sorted order
    assert_select "th[aria-sort=descending] a", text: "打席 ▼"
  end

  test "sorting ascending" do
    add_batters_of_different_size

    get rankings_url, params: { season: "2026-spring", sort: "pa", direction: "asc" }

    assert_equal %w[一位 二位 三位], ranked_names
    assert_select "th[aria-sort=ascending] a", text: "打席 ▲"
  end

  test "without a sort the ranking's own order is shown, with the rank column marked" do
    add_batters_of_different_size

    get rankings_url, params: { season: "2026-spring" }

    assert_equal %w[一位 二位 三位], ranked_names
    assert_select "th[aria-sort=ascending] a", text: "順位 ▲"
    assert_select "th[aria-sort]", 1
  end

  test "a sort without a direction uses the column's natural order" do
    add_batters_of_different_size

    get rankings_url, params: { season: "2026-spring", sort: "pa" }

    assert_equal %w[三位 二位 一位], ranked_names # largest first
  end

  test "an invalid sort or direction is ignored" do
    add_batters_of_different_size

    get rankings_url, params: { season: "2026-spring", sort: "wins", direction: "sideways" }

    assert_response :success
    assert_equal %w[一位 二位 三位], ranked_names
    assert_select "th[aria-sort=ascending] a", text: "順位 ▲"
  end

  test "each heading links to sort by it: largest first, or reversed if it is the current sort" do
    add_batters_of_different_size

    get rankings_url, params: { season: "2026-spring" }
    assert_select "thead th a[href*='sort=pa'][href*='direction=desc']", text: "打席"
    assert_select "thead th a[href*='sort=player'][href*='direction=asc']", text: "選手"
    assert_select "thead th a[href*='sort=rank'][href*='direction=desc']", text: "順位 ▲" # already sorted by it: reverse
    assert_select "thead th a[href*='season=2026-spring']", minimum: 12                  # the period is kept

    get rankings_url, params: { season: "2026-spring", sort: "pa", direction: "desc" }
    assert_select "thead th a[href*='sort=pa'][href*='direction=asc']", text: "打席 ▼"
  end

  test "every column of both rankings can be sorted" do
    bat(player("打者"), game(@spring, 1), pa: 250) # a career's worth, so both tables have a row to head
    pitch(player("投手"), game(@spring, 2), outs: 300)

    RankingsHelper::COLUMNS.each do |kind, columns|
      columns.each do |key, _label|
        get ranking_url(kind), params: { sort: key }

        assert_response :success, "#{kind} sorted by #{key}"
        assert_select "th[aria-sort] a", 1, "#{kind} sorted by #{key}"
      end
    end
  end

  test "the sort is applied before paging, across all the pages" do
    (1..51).each { |i| bat(player("選手#{i.to_s.rjust(2, '0')}"), game(@spring, i), pa: 100 - i, total_bases: 12 + i) } # more PA means a worse OPS rank

    get rankings_url, params: { season: "2026-spring", sort: "pa", direction: "asc" }

    assert_equal "選手51", ranked_names.first # the fewest plate appearances, though its OPS rank is 1
    assert_equal "1", css_select("tbody tr td:first-child").first.text
  end

  test "the paging links keep the sort, and leave out an invalid one" do
    (1..51).each { |i| bat(player("選手#{i.to_s.rjust(2, '0')}"), game(@spring, i), total_bases: 12 + i) }

    get rankings_url, params: { season: "2026-spring", sort: "hits", direction: "desc" }
    assert_select "nav.pagination a[rel=next][href*='sort=hits'][href*='direction=desc'][href*='page=2']"

    get rankings_url, params: { season: "2026-spring", sort: "bogus" }
    assert_select "nav.pagination a[rel=next]"
    assert_select "nav.pagination a[rel=next][href*='sort=']", 0
  end

  test "the filter form keeps a chosen sort in hidden fields, and has none by default" do
    bat(player("選手"), game(@spring, 1))

    get rankings_url, params: { season: "2026-spring", sort: "pa", direction: "asc" }
    assert_select "form input[type=hidden][name=sort][value=pa]"
    assert_select "form input[type=hidden][name=direction][value=asc]"

    get rankings_url, params: { season: "2026-spring" }
    assert_select "form input[type=hidden][name=sort]", 0
    assert_select "form input[type=hidden][name=direction]", 0
  end

  test "switching to the other ranking drops the sort but keeps the period and universities" do
    get rankings_url, params: { season: "2026-spring", sort: "pa", direction: "asc", university_ids: [ @beta.id ] }

    assert_select ".period-toolbar a.period-btn[href*='season=2026-spring'][href*='university_ids']", text: "投手"
    assert_select ".period-toolbar a.period-btn[href*='sort=']", 0
  end

  test "the ERA table sorts by its own columns" do
    pitch(player("勝ち頭"), game(@spring, 1), outs: 90, earned_runs: 20, wins: 5)
    pitch(player("防御率良い"), game(@spring, 2), outs: 90, earned_runs: 2, wins: 1)

    get ranking_url("pitching"), params: { season: "2026-spring", sort: "wins", direction: "desc" }

    assert_equal %w[勝ち頭 防御率良い], ranked_names
    assert_select "th[aria-sort=descending] a", text: "勝 ▼"
  end

  test "sorting by university and by name" do
    bat(player("ベータの選手", university: @beta), game(@spring, 1))
    bat(player("アルファの選手", university: @alpha), game(@spring, 2))

    get rankings_url, params: { season: "2026-spring", sort: "university" }
    assert_equal %w[アルファの選手 ベータの選手], ranked_names

    get rankings_url, params: { season: "2026-spring", sort: "university", direction: "desc" }
    assert_equal %w[ベータの選手 アルファの選手], ranked_names
  end

  test "the page tells the reader that headings sort and the ranks are renumbered" do
    get rankings_url

    assert_select "p.muted", text: /見出しをクリックすると並べ替えられ、順位もその列の順につけ直されます/
  end

  test "the tab buttons are labelled 打者 and 投手" do
    get rankings_url

    assert_equal %w[打者 投手], css_select(".period-toolbar a.period-btn").map { |a| a.text.strip }
  end

  test "equal values in the sorted column share a rank on the page, and sorting by rank keeps the official ranks" do
    bat(player("同じ一"), game(@spring, 1), pa: 40)
    bat(player("同じ二"), game(@spring, 2), pa: 40)
    bat(player("少ない"), game(@spring, 3), pa: 30, hits: 1, total_bases: 1)

    get rankings_url, params: { season: "2026-spring", sort: "pa", direction: "desc" }
    assert_equal %w[1 1 3], css_select("tbody tr td:first-child").map(&:text)

    get rankings_url, params: { season: "2026-spring", sort: "rank", direction: "desc" }
    assert_equal %w[少ない 同じ一 同じ二], ranked_names
    assert_equal %w[3 1 1], css_select("tbody tr td:first-child").map(&:text) # the OPS ranks, worst first
  end
end
