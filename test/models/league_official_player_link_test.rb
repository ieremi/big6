require "test_helper"

class LeagueOfficialPlayerLinkTest < ActiveSupport::TestCase
  setup do
    @alpha = universities(:one)
    @game = games(:one)
  end

  def add_player(scorebook_id, name, **attributes)
    Player.create!({ scorebook_id: scorebook_id, university: @alpha, name: name, enter_year: 2023, role: "選手", enrollment_status: 1 }.merge(attributes))
  end

  # A player's page on the league's site, as it heads itself.
  def page_html(name, heading)
    "<table><tr><td><span class=\"subtitle\">#{name}</span></td><td class=\"text14px\">#{heading}</td></tr></table>"
  end

  # A LeagueOfficialPlayerLink reading pages from `pages` (ID => HTML) instead
  # of the league's site, and not waiting between them; `fetched` collects the URLs read.
  def link_with(pages, fetched = [])
    link = LeagueOfficialPlayerLink.new
    link.define_singleton_method(:fetch) { |url| fetched << url; pages[url[/p=(\w+)/, 1]] }
    link.define_singleton_method(:sleep) { |_seconds| }
    link
  end

  def lineup!(*entries)
    @game.update!(league_official_data: { "lineup" => entries.map { |entry| { "side" => "top" }.merge(entry) } })
  end

  test "reads a player's full name, year of entry and high school from the page, and nothing from a graduate's" do
    link = LeagueOfficialPlayerLink.new

    assert_equal LeagueOfficialPlayerLink::Page.new(name: "上田 太陽", enter_year: 2023, high_school: "國學院久我山"),
      link.parse(page_html("上田 太陽", "（2023年入学・國學院久我山）"))
    assert_nil link.parse(page_html("", "（2018年入学・）"))
  end

  test "links the one player of the university and year with the page's full name" do
    player = add_player(1, "上田 太陽")
    add_player(2, "上田 太陽", enter_year: 2024) # another year's

    linked = link_with("AK23UT0" => page_html("上田 太陽", "（2023年入学・國學院久我山）")).link(@alpha, "AK23UT0")

    assert_equal player, linked
    assert_equal "AK23UT0", player.reload.league_official_id
  end

  test "matches kanji written differently on the two sites" do
    player = add_player(1, "高橋 宏崎")

    link_with("AK23TH0" => page_html("髙橋 宏﨑", "（2023年入学・慶應）")).link(@alpha, "AK23TH0")

    assert_equal "AK23TH0", player.reload.league_official_id
  end

  test "links nobody when the page names nobody, or two players could be the one" do
    add_player(1, "鈴木 一郎")
    add_player(2, "鈴木 一郎")

    link = link_with("AK23SI0" => page_html("鈴木 一郎", "（2023年入学・慶應）"), "AK18NK0" => page_html("", "（2018年入学・）"))

    assert_nil link.link(@alpha, "AK23SI0")
    assert_nil link.link(@alpha, "AK18NK0")
    assert_equal 0, Player.where.not(league_official_id: nil).count
  end

  test "a game's lineup reads the pages of the players not linked yet, once each" do
    add_player(1, "上田 太陽")
    add_player(2, "吉野 太陽", league_official_id: "AK23YT1")
    lineup!({ "name" => "上田", "id" => "AK23UT0" }, { "name" => "吉野", "id" => "AK23YT1" }, { "name" => "上田", "id" => "AK23UT0" }, { "name" => "林" })
    fetched = []

    linked = link_with({ "AK23UT0" => page_html("上田 太陽", "（2023年入学・國學院久我山）") }, fetched).link_lineup(@game)

    assert_equal [ "上田 太陽" ], linked.map(&:name)
    assert_equal [ "AK23UT0" ], fetched.map { |url| url[/p=(\w+)/, 1] }
  end

  test "reads at most MAX_FETCHES pages in one go" do
    ids = (0..LeagueOfficialPlayerLink::MAX_FETCHES).map { |n| format("AK23X%02d", n) }
    lineup!(*ids.map { |id| { "name" => "某", "id" => id } })
    fetched = []

    link_with({}, fetched).link_lineup(@game)

    assert_equal LeagueOfficialPlayerLink::MAX_FETCHES, fetched.size
  end
  test "a page is read in the charset the server names, Shift_JIS included" do
    sjis = page_html("髙橋 宏﨑", "（2023年入学・慶應）").encode(Encoding::Windows_31J).b

    assert_equal "髙橋 宏﨑", LeagueOfficialPlayerLink.new.parse(LeagueOfficialPlayerLink.decode(sjis, "SJIS")).name
    assert_equal "上田", LeagueOfficialPlayerLink.decode("上田".b, "UTF-8")
    assert_equal "上田", LeagueOfficialPlayerLink.decode("上田".b, nil)
  end
end
