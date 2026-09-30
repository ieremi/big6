require "test_helper"

class LeagueOfficialGameScraperTest < ActiveSupport::TestCase
  setup do
    @meiji = University.create!(name: "明治大学", short_name: "明大", slug: "meiji", position: 12)
    @waseda = University.create!(name: "早稲田大学", short_name: "早大", slug: "waseda", position: 11)
    @season = Season.create!(year: 2026, term: "autumn")
  end

  def game(day, number, order)
    Game.create!(season: @season, team0: @meiji, team1: @waseda, played_on: day, game_number: number, game_order: order)
  end

  test "a game's page on the league's site is found by its sides and round, and headed by its place in the day" do
    url = LeagueOfficialGameScraper.url_for(game("2026-09-27", 1, 1))

    assert_equal "https://big6.gr.jp/system/prog/game.php?m=pc&e=league&s=2026a&gd=2026-09-27&gnd=1&vs=MW1", url
  end

  test "the second game of a day is gnd=2, whatever its round" do
    assert_match "&gnd=2&vs=MW1", LeagueOfficialGameScraper.url_for(game("2026-09-26", 1, 2))
  end

  test "a game with no place in the day falls back to its round, and one before 2005 or not held has no page" do
    assert_match "&gnd=3&vs=MW3", LeagueOfficialGameScraper.url_for(game("2026-09-29", 3, nil))
    assert_nil LeagueOfficialGameScraper.url_for(Game.new(season: Season.new(year: 2004, term: "spring"), team0: @meiji, team1: @waseda, game_number: 1))
    assert_nil LeagueOfficialGameScraper.url_for(Game.new(season: @season, team0: @meiji, team1: @waseda, game_number: nil))
  end
  # ---- the game's status from its page

  # A page with the given innings on the scoreboard ("" for one not played yet)
  # and the start time in its heading, as the league's site shows them.
  def page(top_innings, bottom_innings, heading: "9月30日(水)　第2試合　試合開始13:30　終了　")
    row = ->(letter, innings) { "<tr class=\"gamescore-score-run\"><td>#{letter}</td>#{innings.map { |run| "<td>#{run}</td>" }.join}<td></td></tr>" }
    "<div class=\"gamescore-gameinfo\">#{heading}</div><table>#{row.("M", top_innings)}#{row.("W", bottom_innings)}</table>"
  end

  def scrape(game, html)
    response = Net::HTTPOK.new("1.1", "200", "OK")
    response.instance_variable_set(:@body, html)
    response.instance_variable_set(:@read, true)
    stub_method(Net::HTTP, :get_response, ->(_uri) { response }) { LeagueOfficialGameScraper.call(game) }
    game.reload
  end

  test "a game whose page shows only its scheduled start, with an empty scoreboard, stays 試合前" do
    game = game("2026-09-30", 2, 2)

    scrape(game, page([ "" ] * 9, [ "" ] * 9))

    assert game.scheduled?
    assert_equal "13:30", game.league_official_data["startTime"]
  end

  test "a game becomes 試合中 once an inning on its scoreboard has runs, a 0 included" do
    game = game("2026-09-30", 2, 2)

    scrape(game, page([ "0" ] + [ "" ] * 8, [ "" ] * 9))

    assert game.in_progress?
  end
  # ---- the pitchers, from the page's smartphone layout

  # A team's block in the smartphone layout: its letter, its batters' table and its pitchers'.
  def team_block(letter, batters, pitchers)
    batter_rows = batters.map { |code, name, school| "<tr class=\"gamescore-box-content\"><td class=\"gamescore-box-position\">#{code}</td><td>#{name}</td><td>#{school}</td><td></td></tr>" }
    pitcher_rows = pitchers.map { |name, school| "<tr class=\"gamescore-box-content\"><td>#{name}</td><td>#{school}</td><td></td></tr>" }
    "<table><tr><td class=\"gamescore-box-teamname\">#{letter}</td></tr></table><table>#{batter_rows.join}</table><table>#{pitcher_rows.join}</table>"
  end

  test "each team's pitchers come from the smartphone layout while the game is on, the first marked as the starter" do
    game = game("2026-09-30", 1, 1)
    sp = team_block("M", [ [ "[8]", "丸田", "(3 慶應)" ] ], [ [ "広池", "(4 慶應)" ], [ "鈴木佳", "(2 慶應)" ] ]) +
      team_block("W", [ [ "[6]", "小林隼", "(3 広陵)" ] ], [ [ "田中", "(3 仙台育英)" ] ])

    scrape(game, page([ "0" ] + [ "" ] * 8, [ "" ] * 9) + "<div id=\"game_scoreboard_sp\">#{sp}</div>")

    pitchers = game.league_official_data["lineup"].reject { |entry| entry["order"] }
    assert_equal [ [ "top", "広池", "投" ], [ "top", "鈴木佳", nil ], [ "bottom", "田中", "投" ] ],
      pitchers.map { |entry| entry.values_at("side", "name", "position") }
    assert_equal [ 4, "慶應" ], pitchers.first.values_at("grade", "high_school")
  end
end
