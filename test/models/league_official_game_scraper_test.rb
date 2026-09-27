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
end
