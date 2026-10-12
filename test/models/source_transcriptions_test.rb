require "test_helper"

# The transcriptions of printed sources in db/sources (see the README there):
# the arithmetic a misread digit would break, checked wherever the book itself
# gives two figures that should agree. Where the book disagrees with itself,
# the file lists it under discrepancies, and that check is skipped.
class SourceTranscriptionsTest < ActiveSupport::TestCase
  FILES = Dir[Rails.root.join("db/sources/**/*.yml")].sort
  SLUGS = %w[waseda keio meiji hosei tokyo rikkio].freeze

  def self.each_file(&block)
    FILES.each { |path| block.call(path, YAML.safe_load_file(path, permitted_classes: [ Date ])) }
  end

  test "there is something to check" do
    assert FILES.any?
  end

  each_file do |path, data|
    name = path.delete_prefix(Rails.root.join("db/sources/").to_s)
    known = Array(data["discrepancies"]).map { |d| d["where"] }

    test "#{name}: every game is of the season, between two of the six, and the line scores add up to the scores" do
      data["games"].each_with_index do |game, i|
        assert_equal data.dig("season", "year"), game["date"].year, "games[#{i}]"
        assert_equal 2, game["score"].size, "games[#{i}]"
        assert (game["score"].keys - SLUGS).empty?, "games[#{i}]: #{game['score'].keys}"
        next unless game["line_score"]

        assert_equal game["score"].keys.sort, game["line_score"].keys.sort, "games[#{i}]"
        assert_equal game["score"].keys.sort, [ game["top"], game["bottom"] ].sort, "games[#{i}]"
        game["line_score"].each do |team, innings|
          runs = innings.delete(" ").chars.reject { |c| c == "x" }.sum(&:to_i)
          assert_equal game.dig("score", team), runs, "games[#{i}] #{team}: #{innings}"
        end
        assert_match(/x\z/, game.dig("line_score", game["bottom"])) if game.dig("score", game["bottom"]) > game.dig("score", game["top"])
      end
    end

    test "#{name}: every column of a box score adds up to its total row" do
      data["games"].each_with_index do |game, i|
        Hash(game["batting"]).each do |team, rows|
          next if known.include?("games[#{i}].totals.#{team}")

          sums = rows.map { |row| row[2..6] }.transpose.map(&:sum)
          assert_equal game.dig("totals", team), sums, "games[#{i}] #{team}"
        end
      end
    end

    test "#{name}: a team's total bases and average agree with its hits" do
      Hash(data.dig("year_batting", "teams")).each do |team, (_games, ab, _runs, hits, bases, doubles, triples, homers, *, average)|
        assert_equal bases, hits + doubles + 2 * triples + 3 * homers, team
        next if known.include?("year_batting.teams.#{team}")

        assert_equal average, format("%.3f", (hits.to_f / ab).round(3)).sub(/\A0/, ""), team
      end

      Array(data.dig("year_batting", "rikkio_players")).each do |name, _games, ab, _runs, hits, bases, doubles, triples, homers, *, average|
        assert_equal average, format("%.3f", (hits.to_f / ab).round(3)).sub(/\A0/, ""), name
        next if known.include?("year_batting.rikkio_players[#{name}]")

        assert_equal bases, hits + doubles + 2 * triples + 3 * homers, name
      end
    end
  end
end
