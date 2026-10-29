# Adds a game from a transcription of a printed source (db/sources, e.g. the
# club history 『立教大学野球部史』) to the site: a game Scorebook doesn't have.
# The game gets its result and round from the transcription, its line score,
# ground and hits in the shape of Scorebook's own game data
# (Game#source_scoreboard, which GameScoreboard shows), and the citation, so the
# game page and the API say where it comes from.
#
# Only the game itself is added: no players or batting lines, since the
# players of those years aren't in Scorebook's 名鑑 and many transcribed box
# scores give only names. Running it again updates the same game.
#
# A club's history has only that club's games, so a season imported this way
# is partial (Season#from_printed_sources?): its standings are the printed
# table (Season#source_standings), not worked out from the games.
class SourceGameImport
  # The book each directory of db/sources transcribes, as it is cited.
  CITATIONS = {
    "rikkyo_yakyubushi_1981" => "立教大学野球部 編『立教大学野球部史』（1981年）"
  }.freeze

  # path: a transcription file, e.g. db/sources/rikkyo_yakyubushi_1981/1924_autumn.yml.
  # played_on: the date of the game to add from it.
  def self.call(path, played_on:)
    new(path).call(played_on: played_on)
  end

  # Every game of the file that has a line score, and the season's standings
  # (勝敗表) as printed (Season#source_standings). A game with no line score is
  # skipped: which side batted first isn't known. A game outside the league's
  # table (playoff, such as 1928 autumn's 3位決定戦) is added too, not counted
  # in stats and named by its playoff (Game#playoff). Returns the games added
  # and the dates skipped.
  def self.season(path)
    new(path).season
  end

  def initialize(path)
    @path = Pathname(path)
    @data = YAML.safe_load_file(@path, permitted_classes: [ Date ])
  end

  def season
    added, skipped = @data["games"].partition { |entry| entry["top"] && entry["bottom"] }
    games = added.map { |entry| import(entry) }
    find_season.update!(source_standings: standings) if @data["standings"]
    [ games, skipped.map { |entry| entry["date"] } ]
  end

  # The game on played_on. A day with two games in the file (a misprinted date,
  # as 1928 autumn's 帝大1回戦) is refused: import the whole file instead.
  def call(played_on:)
    entries = @data["games"].select { |game| game["date"] == played_on }
    raise ArgumentError, "#{@path}: no game on #{played_on}" if entries.empty?
    raise ArgumentError, "#{@path}: #{entries.size} games on #{played_on}; import the whole file" if entries.size > 1

    import(entries.first)
  end

  private

  def import(entry)
    played_on = entry["date"]
    raise ArgumentError, "#{@path}: the game on #{played_on} has no line score, so its home and away sides aren't known" unless entry["top"] && entry["bottom"]

    season = find_season
    top = University.find_by!(slug: entry["top"])
    bottom = University.find_by!(slug: entry["bottom"])

    game = Game.find_or_initialize_by(season: season, played_on: played_on, team0: top, team1: bottom)
    game.update!(
      game_number: entry["round"] || next_round(game, top, bottom),
      playoff: entry["playoff"],
      counted_in_stats: !entry["playoff"],
      team0_score: entry.dig("score", entry["top"]),
      team1_score: entry.dig("score", entry["bottom"]),
      game_status: "試合終了",
      source_citation: citation,
      source_url: @data.dig("source", "ndl_url"),
      source_scoreboard: scoreboard(entry)
    )
    game
  end

  # A playoff's number: the pair's next in the season after its games (the
  # URL of a game page names its round), as Scorebook numbers its 優勝決定戦
  # after the pair's three games (2024 autumn's 明大-早大 is a 4回戦).
  def next_round(game, top, bottom)
    others = Game.where(season: game.season, team0_id: [ top.id, bottom.id ], team1_id: [ top.id, bottom.id ]).where.not(id: game.id)
    others.maximum(:game_number).to_i + 1
  end

  def find_season
    Season.find_by!(year: @data.dig("season", "year"), term: @data.dig("season", "term"))
  end

  # The printed 勝敗表, in its own order: for each university the games, wins,
  # losses, draws, 勝ち点 (in the tables that have it) and 勝率 as printed, and
  # its cell against each opponent ("2", "1△", "×" for no games, "：" or "×"
  # for itself), with the citation.
  def standings
    table = @data["standings"]
    opponents, columns = table.values_at("opponents", "columns")
    rows = table["teams"].map do |slug, row|
      stats = columns.zip(row.last(columns.size)).to_h
      {
        "university" => slug,
        "games" => row.first,
        "wins" => stats.fetch("wins"),
        "losses" => table.dig("losses", slug),
        "draws" => stats.fetch("draws", 0),
        "points" => stats["points"],
        "average" => stats.fetch("average"),
        "cells" => opponents.zip(row[1, opponents.size]).to_h
      }
    end
    { "citation" => citation, "url" => @data.dig("source", "ndl_url"), "opponents" => opponents, "self_mark" => table["self_mark"], "rows" => rows }
  end

  def citation
    book = CITATIONS.fetch(@path.dirname.basename.to_s)
    pages = @data.dig("source", "pages").to_s
    "#{book}#{pages.match?(/\D/) ? "pp." : "p."}#{pages.tr("-", "–")}"
  end

  # Scorebook's keys: runs per inning as strings, "X" for a bottom half not
  # played, and the hits and errors totals where the box score gives them.
  def scoreboard(entry)
    detail = { "stadium" => entry["venue"] }
    { "Top" => entry["top"], "Bottom" => entry["bottom"] }.each do |half, team|
      entry.dig("line_score", team).delete(" ").chars.each.with_index(1) do |runs, inning|
        detail["runs#{inning}#{half}"] = runs == "x" ? "X" : runs
      end

      if (totals = entry.dig("totals", team))
        detail["hitsTotal#{half}"] = totals[1].to_s
        detail["errorsTotal#{half}"] = totals[4].to_s
      elsif (totals = entry.dig("lineup_totals", team))
        detail["hitsTotal#{half}"] = totals[1].to_s
      end
    end
    detail.compact
  end
end
