require "net/http"
require "uri"
require "nokogiri"

# Scrapes a single game's box score from the official league site
# (big6.gr.jp) as a provisional stand-in until Scorebook publishes the
# complete data. Caches the result on Game#league_official_data. See
# LeagueOfficialScoreboard for how it's read back for display.
class LeagueOfficialGameScraper
  TEAM_LETTERS = {
    "waseda" => "W",
    "keio" => "K",
    "meiji" => "M",
    "hosei" => "H",
    "tokyo" => "T",
    "rikkio" => "R"
  }.freeze

  def self.call(game)
    new(game).call
  end

  def initialize(game)
    @game = game
  end

  def call
    url = game_url
    return nil unless url

    response = Net::HTTP.get_response(URI(url))
    return nil unless response.is_a?(Net::HTTPSuccess)

    data = parse(Nokogiri::HTML(response.body))
    return nil unless data

    @game.update!(attrs_from(data))
    data
  end

  private

  # Only fills in the game's actual score once the official site shows it as
  # finished (finishTime present), and only if we don't already have a score
  # from Scorebook — Scorebook stays the source of truth once it catches up.
  # Without this, pages that read Game#team0_score/team1_score directly (the
  # season schedule, standings, etc.) keep showing the game as not-yet-played
  # even though the individual game page already has a provisional box score.
  def attrs_from(data)
    attrs = { league_official_data: data }

    if data["finishTime"].present? && @game.team0_score.nil? && @game.team1_score.nil?
      attrs[:team0_score] = data["runsTop"].compact.sum
      attrs[:team1_score] = data["runsBottom"].compact.sum
      attrs[:game_status] = "finished"
    end

    if @game.attendance.nil? && data["attendance"].present?
      attrs[:attendance] = data["attendance"].to_i
    end

    attrs
  end

  # Mirrors GamesHelper#league_official_game_url without depending on a view
  # helper module from a plain model.
  def game_url
    return nil if @game.season.year < 2005

    term_code = @game.season.term == "spring" ? "s" : "a"
    vs = "#{@game.team0.initial}#{@game.team1.initial}#{@game.game_number}"

    "https://big6.gr.jp/system/prog/game.php?m=pc&e=league&s=#{@game.season.year}#{term_code}" \
      "&gd=#{@game.played_on}&gnd=#{@game.game_number}&vs=#{vs}"
  end

  def parse(doc)
    score_rows = doc.css(".gamescore-score-run").first(2)
    return nil if score_rows.size < 2

    runs_by_letter = score_rows.each_with_object({}) do |row, h|
      cells = row.css("td")
      letter = cells[0].text.strip
      h[letter] = cells[1..-2].map { |c| c.text.strip.presence&.to_i }
    end

    runs_top = runs_by_letter[TEAM_LETTERS.fetch(@game.team0.slug)]
    runs_bottom = runs_by_letter[TEAM_LETTERS.fetch(@game.team1.slug)]
    return nil unless runs_top && runs_bottom

    info_text = doc.at_css(".gamescore-gameinfo")&.text.to_s
    hits = total_hits(doc)

    {
      "runsTop" => runs_top,
      "runsBottom" => runs_bottom,
      "hitsTop" => hits[0],
      "hitsBottom" => hits[1],
      "startTime" => info_text[/試合開始(\d{1,2}:\d{2})/, 1],
      "finishTime" => info_text[/終了(\d{1,2}:\d{2})/, 1],
      "attendance" => info_text[/観衆\s*([\d,]+)人/, 1]&.delete(","),
      "umpires" => umpires(doc),
      "stadium" => "神宮球場"
    }
  end

  def total_hits(doc)
    totals = doc.css(".gamescore-box-content")
      .select { |row| row.at_css(".game_player")&.text&.strip == "計" }
      .first(2)

    totals.map { |row| row.css("td")[4]&.text&.strip.presence&.to_i }
  end

  def umpires(doc)
    text = doc.at_css(".gamescore-umpire")&.text.to_s
    text.split(/［[^］]+］/)
      .flat_map { |segment| segment.split("・") }
      .map { |name| name.gsub("　", "").strip }
      .reject(&:empty?)
  end
end
