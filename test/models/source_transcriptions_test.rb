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
        next if known.include?("games[#{i}].line_score")

        assert_equal game["score"].keys.sort, game["line_score"].keys.sort, "games[#{i}]"
        assert_equal game["score"].keys.sort, [ game["top"], game["bottom"] ].sort, "games[#{i}]"
        game["line_score"].each do |team, innings|
          runs = innings.delete(" ").chars.reject { |c| c == "x" }.sum(&:to_i)
          assert_equal game.dig("score", team), runs, "games[#{i}] #{team}: #{innings}"
        end
        assert_match(/x\z/, game.dig("line_score", game["bottom"])) if game.dig("line_score", game["bottom"]).delete(" ").size <= 9 && game.dig("score", game["bottom"]) > game.dig("score", game["top"])
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

    if data["year_batting"]
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

    # 勝敗表: each cell is the wins against that opponent, plus one △ per draw in
    # books that mark draws there. The columns after the cells (勝・分・勝点・率)
    # vary from table to table, so the file names them, and says whether the
    # average is taken over all games or over decisions only.
    if (standings = data["standings"]) && !known.include?("standings")
      test "#{name}: the standings agree with themselves" do
        opponents, teams, columns = standings.values_at("opponents", "teams", "columns")
        cell = ->(team, other) { teams[team][1 + opponents.index(other)] }
        wins_against = ->(team, other) { cell.(team, other).to_i }
        draws_against = ->(team, other) { cell.(team, other).count("△") }
        marks_draws = teams.values.flatten.any? { |value| value.to_s.include?("△") }

        teams.each do |team, row|
          games = row.first
          stats = columns.zip(row.last(columns.size)).to_h
          others = opponents - [ team ]
          wins = others.sum { |other| wins_against.(team, other) }
          losses = others.sum { |other| wins_against.(other, team) }
          draws = stats.fetch("draws", 0)
          assert_equal standings["self_mark"], cell.(team, team), team
          assert_equal stats["wins"], wins, team
          assert_equal standings.dig("losses", team), losses, team
          assert_equal games, wins + losses + draws, team
          if marks_draws
            assert_equal draws, others.sum { |other| draws_against.(team, other) }, team
            others.each { |other| assert_equal draws_against.(other, team), draws_against.(team, other), "#{team} #{other}" }
          end
          if stats.key?("points")
            assert_equal stats["points"], others.count { |other| wins_against.(team, other) > wins_against.(other, team) }, team
          end
# Rounded in most tables, truncated in some (法政's .166 in 1923 spring).
ratio = Rational(wins, standings["average"] == "wins_per_game" ? games : wins + losses) * 1000
candidates = ratio == 1000 ? [ "1.000" ] : [ ratio.round, ratio.floor ].map { |digits| format(".%03d", digits) }
assert_includes candidates, stats["average"], team
        end
      end
    end

    # チーム守備成績: the book prints the fielding average to three or four
    # places, sometimes rounded and sometimes truncated, even within one table.
    if (fielding = data["team_fielding"])
      test "#{name}: the fielding averages agree with the chances" do
        fielding.each do |team, row|
          next if known.include?("team_fielding.#{team}")

          putouts, assists, errors, average = row.last(4)
          places = average.length - 1
          ratio = Rational(putouts + assists, putouts + assists + errors) * 10**places
          candidates = [ ratio.floor, ratio.round ].map { |digits| ".#{digits.to_s.rjust(places, "0")}" }
          assert_includes candidates, average, team
        end
      end
    end

    # チーム攻撃成績 and 立教's individual batting for the season: each row's
    # average and total bases agree with its hits, and 立教's players add up
    # to 立教's row. The players' table may order its columns differently
    # (player_columns). A discrepancy can name one column of a row
    # (season_batting.teams.rikkio.<column>) to skip just that check.
    if (season = data["season_batting"])
      test "#{name}: the season batting agrees with itself" do
        columns = season["columns"]
        player_columns = season.fetch("player_columns", columns)
        average = ->(at) { format("%.3f", (at.("安打").to_f / at.("打撃数")).round(3)).sub(/\A0/, "") }
        bases = ->(at) { at.("安打") + at.("二塁打") + 2 * at.("三塁打") + 3 * at.("本塁打") }
        check = lambda do |label, key, at|
          assert_equal at.("打撃率"), average.(at), label unless known.include?("#{key}.打撃率")
          assert_equal at.("塁打数"), bases.(at), label if columns.include?("塁打数") && !known.include?("#{key}.塁打数")
        end

        season["teams"].each do |team, row|
          next if known.include?("season_batting.teams.#{team}")

          check.(team, "season_batting.teams.#{team}", ->(column) { row[columns.index(column)] })
        end

        players = Array(season["rikkio_players"]).map { |name, *row| [ name, ->(column) { row[player_columns.index(column)] } ] }
        players.each { |name, at| check.(name, "season_batting.rikkio_players[#{name}]", at) }
        # Some tables list only part of the team (rikkio_players_partial).
        if players.any? && !season["rikkio_players_partial"]
          team = season.dig("teams", "rikkio")
          ((columns - %w[試合数 打撃率]) & player_columns).each do |column|
            next if known.include?("season_batting.teams.rikkio.#{column}")

            assert_equal team[columns.index(column)], players.sum { |_, at| at.(column) }, column
          end
        end
      end
    end

    # 個人打撃成績 (the league's leaders): average against hits and at-bats.
    if (leaders = data["batting_leaders"])
      test "#{name}: the batting leaders' averages agree with their hits" do
        leaders.each do |name, _university, _games, at_bats, hits, average|
          next if known.include?("batting_leaders[#{name}]")

          assert_equal average, format("%.3f", (hits.to_f / at_bats).round(3)).sub(/\A0/, ""), name
        end
      end
    end
  end
end
