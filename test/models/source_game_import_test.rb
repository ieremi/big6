require "test_helper"

class SourceGameImportTest < ActiveSupport::TestCase
  FILE = Rails.root.join("db/sources/rikkyo_yakyubushi_1981/1924_autumn.yml")

  setup do
    @season = Season.create!(year: 1924, term: "autumn")
    @hosei = University.create!(name: "Hosei University", short_name: "法大", slug: "hosei", position: 14)
    @rikkio = University.create!(name: "Rikkio University", short_name: "立大", slug: "rikkio", position: 16)
    @keio = University.create!(name: "Keio University", short_name: "慶大", slug: "keio", position: 12)
  end

  test "adds the game with its result, round and the source cited" do
    game = SourceGameImport.call(FILE, played_on: Date.new(1924, 9, 24))

    assert_equal [ @season, @rikkio, @hosei, 7, 2, 1, "finished" ],
      [ game.season, game.team0, game.team1, game.team0_score, game.team1_score, game.game_number, game.game_status ]
    assert_equal "立教大学野球部 編『立教大学野球部史』（1981年）pp.29–31", game.source_citation
    assert_equal "https://dl.ndl.go.jp/pid/12172714/1/37", game.source_url
    assert_nil game.scorebook_game_id
  end

  test "stores the line score in Scorebook's shape, so the scoreboard shows it" do
    game = SourceGameImport.call(FILE, played_on: Date.new(1924, 9, 24))
    scoreboard = GameScoreboard.new(game)

    assert_equal 1..9, scoreboard.innings
    assert_equal %w[0 0 3 0 0 0 4 0 0], scoreboard.innings.map { |n| scoreboard.top_runs(n) }
    assert_equal %w[2 0 0 0 0 0 0 0 0], scoreboard.innings.map { |n| scoreboard.bottom_runs(n) }
    assert_equal [ 7, 2 ], [ scoreboard.top_total, scoreboard.bottom_total ]
    assert_equal [ "池袋", "4", "5" ], [ scoreboard.stadium, scoreboard.top_hits, scoreboard.bottom_hits ]
  end

  test "gives a bottom half not played as X, and the errors where the box score has them" do
    game = SourceGameImport.call(FILE, played_on: Date.new(1924, 10, 24))
    scoreboard = GameScoreboard.new(game)

    assert_equal [ @rikkio, @keio, 2, 7 ], [ game.team0, game.team1, game.team0_score, game.team1_score ]
    assert_equal "X", scoreboard.bottom_runs(9)
    assert_equal [ "4", "1" ], [ scoreboard.top_errors, scoreboard.bottom_errors ]
  end

  test "updates the same game when run again" do
    first = SourceGameImport.call(FILE, played_on: Date.new(1924, 9, 24))
    again = SourceGameImport.call(FILE, played_on: Date.new(1924, 9, 24))

    assert_equal first, again
    assert_equal 1, Game.where(season: @season).count
  end

  test "refuses a date with no game in the file" do
    assert_raises(ArgumentError) { SourceGameImport.call(FILE, played_on: Date.new(1924, 9, 25)) }
  end

  test "adds every game of a file that has a line score, and the printed standings" do
    University.create!(name: "Waseda University", short_name: "早大", slug: "waseda", position: 13)
    University.create!(name: "Meiji University", short_name: "明大", slug: "meiji", position: 15)

    games, skipped = SourceGameImport.season(FILE)

    assert_equal 8, games.size
    assert_empty skipped
    table = @season.reload.source_standings
    assert_equal "立教大学野球部 編『立教大学野球部史』（1981年）pp.29–31", table["citation"]
    assert_equal %w[waseda keio meiji rikkio hosei], table["rows"].map { |row| row["university"] }
    assert_equal({ "university" => "rikkio", "games" => 8, "wins" => 2, "losses" => 6, "draws" => 0, "points" => nil, "average" => ".250",
      "cells" => { "waseda" => "0", "keio" => "0", "meiji" => "0", "rikkio" => "：", "hosei" => "2" } }, table["rows"][3])
    assert @season.from_printed_sources?
  end

  test "skips the games of a file with no line score" do
    season = Season.create!(year: 1928, term: "spring")
    %w[waseda tokyo meiji].each.with_index(20) { |slug, position| University.create!(name: slug, short_name: slug, slug: slug, position: position) }

    games, skipped = SourceGameImport.season(Rails.root.join("db/sources/rikkyo_yakyubushi_1981/1928_spring.yml"))

    assert_equal 4, games.size
    assert_equal [ Date.new(1928, 5, 5), Date.new(1928, 5, 6), Date.new(1928, 5, 14), Date.new(1928, 5, 15), Date.new(1928, 5, 16) ], skipped
    assert_nil season.reload.source_standings
  end
end
