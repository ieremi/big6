require "net/http"
require "uri"

# Scrapes sportsbull.jp's BIG6TV schedule page
# (https://sportsbull.jp/big6tv/schedule/<year><s|a>/) for each game's full
# match replay link ("フルマッチ動画", a 見逃し配信 page under /p/<id>/), and
# stores it on the matching Game row. Not every season has these — the
# schedule only started linking full match replays from around 2023; older
# seasons only have highlight reels, which this intentionally ignores (a
# highlight isn't the "動画配信" a visitor following the link would expect).
#
# The page is a Next.js app that streams content out of order: unrelated
# sections (footer, ranking sidebar) occasionally land mid-response and
# split a game entry across a large gap. GAME_PATTERN's tight, bracket-free
# gaps mean a split entry simply fails to match rather than matching
# garbage, so a handful of entries are silently skipped each run instead of
# risking a wrong link. Matches are further confirmed against the game's own
# recorded score before being applied, as a second safety net.
class SportsbullVideoScraper
  TEAM_CODE_TO_SLUG = {
    "K" => "keio", "M" => "meiji", "W" => "waseda",
    "H" => "hosei", "R" => "rikkio", "T" => "tokyo"
  }.freeze

  GAME_PATTERN = %r{
    第\s*\d+\s*試合\s*
    \[LOGO:([A-Z])s\][^\d\[]*?
    (\d+)\s*-\s*(\d+)\s*
    [^\[]*?\[LOGO:([A-Z])s\]\s*
    (?:\[LINK:ハイライト=>/p/\d+/\]\s*)?
    \[LINK:フルマッチ動画=>(/p/\d+/)\]
  }x

  DATE_PATTERN = %r{(\d{1,2})/(\d{1,2})\([^)]*\)}

  Entry = Struct.new(:date, :code0, :score0, :score1, :code1, :path, keyword_init: true)

  def self.call(season)
    new(season).call
  end

  def initialize(season)
    @season = season
  end

  def call
    html = fetch_html
    return [] unless html

    parse(linearize(html)).filter_map { |entry| apply(entry) }
  end

  private

  def fetch_html
    term_code = @season.term == "spring" ? "s" : "a"
    url = "https://sportsbull.jp/big6tv/schedule/#{@season.year}#{term_code}/"

    response = Net::HTTP.get_response(URI(url))
    response.is_a?(Net::HTTPSuccess) ? response.body.dup.force_encoding("UTF-8") : nil
  end

  def linearize(html)
    html = html.gsub(%r{<a\s+[^>]*href="([^"]+)"[^>]*>(.*?)</a>}m) { "[LINK:#{$2}=>#{$1}]" }
    html = html.gsub(%r{<img[^>]*src="([^"]*logo_([A-Z])_s\.png[^"]*)"[^>]*>}m) { "[LOGO:#{$2}s]" }
    html = html.gsub(%r{<script.*?</script>}m, " ")
    html = html.gsub(/<[^>]+>/, " ")
    html.gsub("&amp;", "&").squeeze(" ")
  end

  def parse(text)
    dates = text.to_enum(:scan, DATE_PATTERN).map do
      md = Regexp.last_match
      [ md.begin(0), Date.new(@season.year, md[1].to_i, md[2].to_i) ]
    end

    text.to_enum(:scan, GAME_PATTERN).filter_map do
      md = Regexp.last_match
      date = dates.reverse.find { |offset, _| offset <= md.begin(0) }&.last
      next nil unless date

      Entry.new(date: date, code0: md[1], score0: md[2].to_i, score1: md[3].to_i, code1: md[4], path: md[5])
    end
  end

  def apply(entry)
    team0 = University.find_by(slug: TEAM_CODE_TO_SLUG[entry.code0])
    team1 = University.find_by(slug: TEAM_CODE_TO_SLUG[entry.code1])
    return nil unless team0 && team1

    candidates = Game.where(
      season: @season, played_on: entry.date,
      team0_id: [ team0.id, team1.id ], team1_id: [ team0.id, team1.id ]
    ).to_a
    game = candidates.detect { |g| matches_score?(g, team0, entry) } || (candidates.size == 1 ? candidates.first : nil)
    return nil unless game

    url = "https://sportsbull.jp#{entry.path}"
    return nil if game.video_url == url

    game.update!(video_url: url)
    game
  end

  def matches_score?(game, team0, entry)
    if game.team0_id == team0.id
      game.team0_score == entry.score0 && game.team1_score == entry.score1
    else
      game.team1_score == entry.score0 && game.team0_score == entry.score1
    end
  end
end
