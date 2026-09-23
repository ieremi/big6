require "test_helper"

class ScorebookMemberStatsTest < ActiveSupport::TestCase
  def page
    file_fixture("scorebook_member.html").read
  end

  test "reads each game's line, league games and playoffs alike, with its game id and date" do
    lines = ScorebookMemberStats.lines_from(page)

    assert_equal [ 2019041301, 2019041402, 2019060101 ], lines.map(&:scorebook_game_id)
    assert_equal Date.new(2019, 4, 13), lines.first.played_on
    assert_equal({ pa: 4, ab: 4, hits: 2, home_runs: 1, rbi: 2 }, lines.first.values.slice(:pa, :ab, :hits, :home_runs, :rbi))
  end

  test "a value Scorebook didn't record is nil, not 0" do
    first, second, = ScorebookMemberStats.lines_from(page)

    assert_nil first.values[:runs]
    assert_nil first.values[:gidp]
    assert_equal 1, second.values[:runs]
    assert_equal 0, first.values[:doubles]
  end

  test "a page without its embedded data can't be read" do
    assert_nil ScorebookMemberStats.lines_from("<html><body>not found</body></html>")
  end

  test "a player with no batting has no lines" do
    html = page.sub(/"gameStatsBatterData":\{.*\}\}\},"page"/m, '"gameStatsBatterData":null}},"page"')

    assert_equal [], ScorebookMemberStats.lines_from(html)
  end
end
