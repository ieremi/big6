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

  def initialize(path)
    @path = Pathname(path)
    @data = YAML.safe_load_file(@path, permitted_classes: [ Date ])
  end

  def call(played_on:)
    entry = @data["games"].find { |game| game["date"] == played_on }
    raise ArgumentError, "#{@path}: no game on #{played_on}" unless entry
    raise ArgumentError, "#{@path}: the game on #{played_on} has no line score, so its home and away sides aren't known" unless entry["top"] && entry["bottom"]

    season = Season.find_by!(year: @data.dig("season", "year"), term: @data.dig("season", "term"))
    top = University.find_by!(slug: entry["top"])
    bottom = University.find_by!(slug: entry["bottom"])

    game = Game.find_or_initialize_by(season: season, played_on: played_on, team0: top, team1: bottom)
    game.update!(
      game_number: entry["round"],
      team0_score: entry.dig("score", entry["top"]),
      team1_score: entry.dig("score", entry["bottom"]),
      game_status: "試合終了",
      source_citation: citation,
      source_url: @data.dig("source", "ndl_url"),
      source_scoreboard: scoreboard(entry)
    )
    game
  end

  private

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
