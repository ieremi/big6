require "net/http"
require "uri"
require "nokogiri"

# Scrapes a single game's box score from the official league site
# (big6.gr.jp) as a provisional stand-in until Scorebook publishes the
# complete data. Caches the result on Game#league_official_data. See
# LeagueOfficialScoreboard for how it's read back for display, and
# LeagueOfficialLineup for the roster ("lineup" key) scraped alongside it.
class LeagueOfficialGameScraper
  TEAM_LETTERS = {
    "waseda" => "W",
    "keio" => "K",
    "meiji" => "M",
    "hosei" => "H",
    "tokyo" => "T",
    "rikkio" => "R"
  }.freeze

  # Standard Japanese baseball position numbering (the box score's own
  # position codes), 1-9 plus D for the designated hitter.
  POSITION_KANJI = {
    "1" => "投", "2" => "捕", "3" => "一", "4" => "二", "5" => "三",
    "6" => "遊", "7" => "左", "8" => "中", "9" => "右", "D" => "指"
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
  #
  # Likewise, nothing else moves a game off scheduled (試合前) until Scorebook
  # itself reports it under way — which can lag behind the game actually
  # having started by as much as its own polling interval. The official
  # site showing a start time (and not yet a finish time) is itself good
  # enough evidence the game is on, so mark it in_progress from that alone
  # when still scheduled — this is also what in_progress?-gated code (the
  # provisional lineup) waits on to show anything.
  def attrs_from(data)
    attrs = { league_official_data: data }

    if data["finishTime"].present? && @game.team0_score.nil? && @game.team1_score.nil?
      attrs[:team0_score] = data["runsTop"].compact.sum
      attrs[:team1_score] = data["runsBottom"].compact.sum
      attrs[:game_status] = "finished"
    elsif data["startTime"].present? && @game.scheduled?
      attrs[:game_status] = "in_progress"
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
      "stadium" => "神宮球場",
      "lineup" => lineup(doc)
    }
  end

  # Each team's batters, then (only once "計" total rows confirm the
  # boundaries — see parse_pitchers) each team's pitchers. A batter row is
  # [position code, name, "(grade high_school)"]; a pitcher row is
  # [name, "(grade high_school)", innings pitched] — no position code cell.
  # The box score also repeats the same content a second time elsewhere on
  # the page; both parsers stop once they detect that repeat rather than
  # double their result.
  def lineup(doc)
    rows = doc.css(".gamescore-box-content").map { |row| row.css("td").map { |c| c.text.strip } }.reject(&:empty?)
    parse_batters(rows) + parse_pitchers(rows)
  end

  # Splits into two teams from the box score's own content, not from "計"
  # (team total) rows: a starting lineup uses each of the 9 positions
  # (1-9, D for the designated hitter) exactly once, so a starter whose
  # *starting* position repeats one already seen this side means the next
  # team's batters have begun. This still works during a live game's early
  # innings, when the box score has no "計" rows at all yet and both teams'
  # rows would otherwise run together with nothing marking where one ends
  # and the other begins.
  #
  # order (batting order) is only set for a row whose position code is
  # bracketed ("[7]", "[D]") — a starter — counted within that team's
  # batting block only; a bare code ("7"), "H", or "H4" is a substitute who
  # entered partway (defensive sub, pinch hitter, or a pinch hitter who's
  # since taken the field), with no fixed order slot to show here. position
  # shown is wherever a starter is playing *now* — the position after any
  # "[2]3"-style mid-game move — since that's more useful once the game is
  # under way than where they happened to start.
  def parse_batters(rows)
    entries = []
    side = "top"
    seen_starting_positions = Set.new
    batting_order = 0

    rows.each do |cells|
      next unless cells[2]&.match?(/\A\(.*\)\z/)

      starter, starting_position, current_position = position_code_from(cells[0])

      if starter
        if seen_starting_positions.include?(starting_position)
          break if side == "bottom" # both teams done; this is the page's own repeat of its content

          side = "bottom"
          seen_starting_positions.clear
          batting_order = 0
        end
        seen_starting_positions << starting_position
        batting_order += 1
      end

      grade, high_school = grade_and_high_school(cells[2])
      entries << {
        "side" => side, "order" => (starter ? batting_order : nil),
        "position" => POSITION_KANJI[current_position], "name" => cells[1], "grade" => grade, "high_school" => high_school
      }
    end

    entries
  end

  # Unlike batters, a pitcher's row carries nothing that repeats reliably
  # once per team (no fixed position, and a team may have used only one
  # pitcher so far) to split on the same way — so this instead trusts "計"
  # (team total) rows to mark the boundaries, same as the box score does
  # for the whole page in its complete, post-game form. Both totals for
  # batting and then both for pitching are expected in that order; with
  # fewer than that (an early-innings live game has none at all yet, since
  # the pitching total rows come last), there's no reliable split to make,
  # so this returns nothing rather than guess.
  def parse_pitchers(rows)
    entries = []
    phase = 0

    rows.each do |cells|
      if cells.include?("計")
        phase += 1
        break if phase >= 4

        next
      end

      next if phase < 2
      next unless cells[1]&.match?(/\A\(.*\)\z/)

      grade, high_school = grade_and_high_school(cells[1])
      entries << { "side" => (phase == 2 ? "top" : "bottom"), "order" => nil, "position" => "投", "name" => cells[0], "grade" => grade, "high_school" => high_school }
    end

    entries
  end

  # [is a starter, starting position code, current position code] from a
  # batter's position-code cell: "[7]" (started, and still at, 7), "[2]3"
  # (started at 2, now at 3 — the starting code is what's unique per team,
  # the current one is what's worth showing), "7" (defensive sub at 7, no
  # brackets — not a starter), "H"/"H4" (pinch hitter, not yet in the
  # field — not a starter, no position at all).
  def position_code_from(code)
    if (match = code.match(/\A\[([1-9D])\](.*)\z/))
      [ true, match[1], match[2].presence || match[1] ]
    elsif code.match?(/\A[1-9D]\z/)
      [ false, nil, code ]
    else
      [ false, nil, nil ]
    end
  end

  # "(4 三重)" -> [4, "三重"]. Grade or school-name-only forms are rare but
  # real (a school name can itself be one character); grade is nil either
  # way it can't be parsed, rather than risk misreading the school as one.
  def grade_and_high_school(text)
    match = text.match(/\A\((\d)\s*(.*)\)\z/)
    return [ nil, nil ] unless match

    [ match[1].to_i, match[2].presence ]
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
