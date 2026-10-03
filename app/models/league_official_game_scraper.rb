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

    # Decoded first, not left to libxml2: the page says shift_jis but has
    # Windows-31J kanji (髙, 德), and libxml2 stops reading at the first one,
    # losing everything after it (the second team's batters, the pitchers).
    html = LeagueOfficialPlayerLink.decode(response.body, response.type_params["charset"])
    data = parse(Nokogiri::HTML(html, nil, "UTF-8"))
    return nil unless data

    @game.update!(attrs_from(data))
    link_players
    data
  end

  private

  # Links the box score's players to their IDs on the league's site, reading
  # the page of each new one (LeagueOfficialPlayerLink). The box score itself
  # is saved already: a page that can't be read here only leaves those
  # players to be matched the old way (LeagueOfficialLineup), until next time.
  def link_players
    LeagueOfficialPlayerLink.link_lineup(@game)
  rescue StandardError => e
    Rails.logger.error("LeagueOfficialGameScraper: linking players of game #{@game.id}: #{e.class}: #{e.message}")
  end

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
  # enough evidence the game is on, so mark it in_progress from that when
  # still scheduled — this is also what in_progress?-gated code (the
  # provisional lineup) waits on to show anything. The start time alone isn't
  # enough, though: before a game begins its page already shows the
  # *scheduled* start (「試合開始13:30」, with an empty scoreboard), and the
  # hourly SyncRecentGamesJob reads today's games before they start. So the
  # scoreboard must also have something in it: an inning's runs, which appear
  # as each half-inning ends.
  def attrs_from(data)
    attrs = { league_official_data: data }

    if data["finishTime"].present? && @game.team0_score.nil? && @game.team1_score.nil?
      attrs[:team0_score] = data["runsTop"].compact.sum
      attrs[:team1_score] = data["runsBottom"].compact.sum
      attrs[:game_status] = "finished"
    elsif data["startTime"].present? && play_begun?(data) && @game.scheduled?
      attrs[:game_status] = "in_progress"
    end

    if @game.attendance.nil? && data["attendance"].present?
      attrs[:attendance] = data["attendance"].to_i
    end

    attrs
  end

  # Whether any inning on the scoreboard has runs filled in (a 0 counts): a
  # page from before the game has every inning blank.
  def play_begun?(data)
    (data["runsTop"] + data["runsBottom"]).any?
  end

  def game_url
    self.class.url_for(@game)
  end

  # The game's page on the league's site (also linked from the game page,
  # GamesHelper#league_official_game_url), or nil before 2005, when its pages
  # have no box scores. vs is the two sides' initials and the round, as the
  # league numbers its rounds: in the order played (ScorebookSync numbers ours
  # the same way). Under another round the page is an empty box score. gnd is
  # the game's place in the day (第1試合, 第2試合), which the page heads itself
  # with.
  def self.url_for(game)
    return nil if game.season.year < MIN_YEAR || game.game_number.nil?

    term_code = game.season.term == "spring" ? "s" : "a"
    vs = "#{game.team0.initial}#{game.team1.initial}#{game.game_number}"

    "https://big6.gr.jp/system/prog/game.php?m=pc&e=league&s=#{game.season.year}#{term_code}" \
      "&gd=#{game.played_on}&gnd=#{game.game_order || game.game_number}&vs=#{vs}"
  end

  # Before this season the league's game pages have no box scores.
  MIN_YEAR = 2005

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

  # Each team's batters, then each team's pitchers (see pitchers_by_team). A batter row is
  # [position code, name, "(grade high_school)"]; a pitcher row is
  # [name, "(grade high_school)", innings pitched] — no position code cell.
  # The box score also repeats the same content a second time elsewhere on
  # the page; both parsers stop once they detect that repeat rather than
  # double their result.
  #
  # Each entry also gets the player's ID on the league's site ("id", see
  # player_ids), which LeagueOfficialLineup matches players by.
  def lineup(doc)
    rows = doc.css(".gamescore-box-content").map { |row| row.css("td").map { |c| c.text.strip } }.reject(&:empty?)
    entries = parse_batters(rows) + (pitchers_by_team(doc) || parse_pitchers(rows))
    ids = player_ids(doc)
    entries.each { |entry| entry["id"] = ids.dig(entry["side"], entry["name"]) }
  end

  # { side => { short name => the league's player ID } }, from the links on the
  # players' names in the smartphone layout, which says whose team each is (see
  # team_rows). A team's short names are unique: the box score adds the given
  # name's first character just to tell teammates apart. The ID is in the link
  # (kojinseiseki_career_individual.php?p=AK23UT0); 2005's pages have the
  # placeholder "ID" there, which is no ID. See docs/league-site-player-id.md.
  def player_ids(doc)
    ids = Hash.new { |hash, side| hash[side] = {} }
    team_rows(doc).each do |side, row|
      link = row.at_css("a.game_player") or next
      id = link["href"].to_s[/[?&]p=(\w+)/, 1]
      ids[side][link.text.strip] = id if id && id != "ID"
    end
    ids
  end

  # [side, row] for each box score row of the smartphone layout
  # (#game_scoreboard_sp), which, unlike the PC one, gives each team a block of
  # its own: its letter (.gamescore-box-teamname, "K"), its batters' table,
  # then its pitchers'. Empty when the page has no such layout.
  def team_rows(doc)
    layout = doc.at_css("#game_scoreboard_sp") or return []
    sides = { TEAM_LETTERS.fetch(@game.team0.slug) => "top", TEAM_LETTERS.fetch(@game.team1.slug) => "bottom" }
    side = nil

    # One XPath union underneath, so the nodes come in page order.
    layout.css(".gamescore-box-teamname, .gamescore-box-content").filter_map do |node|
      if node["class"].to_s.include?("gamescore-box-teamname")
        side = sides[node.text.strip]
        next
      end
      [ side, node ] if side
    end
  end

  # Each team's pitchers from the page's smartphone layout (team_rows), so
  # the pitchers can be told apart while the game is still on, with no "計"
  # rows yet. They are listed in the order they pitched: the first is the
  # starter, who gets position 投 — as in Scorebook's own roster (GameMember),
  # where the starting pitcher of a game with a designated hitter has 投 and
  # no batting order, and the relievers have no position. nil when the page
  # has no such layout.
  def pitchers_by_team(doc)
    return nil unless doc.at_css("#game_scoreboard_sp")

    entries = []
    team_rows(doc).each do |side, node|
      next if node.at_css(".gamescore-box-position") # a batter

      cells = node.css("td").map { |cell| cell.text.strip }
      next unless cells[1]&.match?(/\A\(.*\)\z/)

      starter = entries.none? { |entry| entry["side"] == side }
      grade, high_school = grade_and_high_school(cells[1])
      entries << { "side" => side, "order" => nil, "position" => (starter ? "投" : nil), "name" => cells[0], "grade" => grade, "high_school" => high_school }
    end

    entries.presence
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

  # For a page without the smartphone layout (pitchers_by_team).
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

      side = phase == 2 ? "top" : "bottom"
      starter = entries.none? { |entry| entry["side"] == side }
      grade, high_school = grade_and_high_school(cells[1])
      entries << { "side" => side, "order" => nil, "position" => (starter ? "投" : nil), "name" => cells[0], "grade" => grade, "high_school" => high_school }
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
