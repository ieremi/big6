require "net/http"
require "uri"
require "json"

# A player's batting, game by game, as Scorebook's own member page
# (big6scorebook.jp/member/<id>) gives it: the lines its season and career totals
# are summed from. Used to check our imported box scores against (see
# ScorebookStatsCheck); the import itself reads each game's page instead
# (GameStatsImport).
#
# A value Scorebook didn't record (runs, GIDP, ... for many older games) is nil,
# not 0: its page shows "-" for those.
class ScorebookMemberStats
  URL = "https://big6scorebook.jp/member/%d".freeze
  USER_AGENT = "big6-stats-check/1.0".freeze

  # Our BattingLine column => Scorebook's key.
  FIELDS = {
    pa: "pa", ab: "ab", runs: "rb", hits: "hb", doubles: "twob", triples: "threeb", home_runs: "hrb",
    rbi: "rbi", strikeouts: "sob", walks: "bbTotal", sacrifices: "sac", stolen_bases: "sb",
    caught_stealing: "cs", gidp: "gidp", fielding_errors: "error"
  }.freeze

  # One of the player's lines: the game's Scorebook id, its date, and the values
  # (FIELDS' keys => Integer, or nil when not recorded).
  Line = Struct.new(:scorebook_game_id, :played_on, :values, keyword_init: true)

  # The player's lines, or nil when the page can't be fetched or read.
  def self.fetch(scorebook_id)
    response = Net::HTTP.get_response(URI(format(URL, scorebook_id)), { "User-Agent" => USER_AGENT })
    response.is_a?(Net::HTTPSuccess) ? lines_from(response.body) : nil
  rescue SocketError, Timeout::Error, SystemCallError
    nil
  end

  # The lines in a member page's HTML ([] for a player with none), or nil when the
  # page has no embedded data. League games and the others (the 優勝決定戦
  # playoffs) alike, as our BattingLines have both.
  def self.lines_from(html)
    html = html.dup.force_encoding(Encoding::UTF_8)
    marker = html.index('id="__NEXT_DATA__"') or return nil
    start = html.index(">", marker) or return nil
    finish = html.index("</script>", start) or return nil
    batting = JSON.parse(html[(start + 1)...finish]).dig("props", "pageProps", "gameStatsBatterData") or return []

    (Array(batting["leagues"]) + Array(batting["others"])).map do |line|
      Line.new(
        scorebook_game_id: line["gameId"],
        played_on: parse_date(line.dig("gameInfo", "gameDay")),
        values: FIELDS.transform_values { |key| line[key]&.to_i }
      )
    end
  rescue JSON::ParserError
    nil
  end

  # Scorebook writes the date "2019/04/28".
  def self.parse_date(value)
    Date.strptime(value.to_s[0, 10].tr("/", "-"), "%Y-%m-%d")
  rescue Date::Error
    nil
  end
end
