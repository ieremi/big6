require "net/http"
require "uri"
require "nokogiri"

# Links our players (from Scorebook's 名鑑) to their IDs on the league's site
# (big6.gr.jp, "AK23UT0"; see docs/league-site-player-id.md), so that the
# players of a box score scraped from there (LeagueOfficialGameScraper) are
# matched for sure, by the ID in the link on each name (LeagueOfficialLineup),
# instead of guessed from the box score's short form of the name ("林純") and
# of the high school ("國學院久我" for 國學院久我山).
#
# The ID alone isn't enough to tell who it is: its last digit only tells apart
# players with the same initials, in an order that isn't known. The player's
# page on the league's site gives the full name, the year of entry and the high
# school, but only while the player is enrolled — which is when they play, so
# it is read the first time an ID turns up in a box score. A player is linked
# only when exactly one of the university's players entering that year has
# that full name; the page is cached, so a player not yet in our 名鑑 (a new
# student Scorebook hasn't listed) is matched again from the cache, not
# fetched again, once they are.
class LeagueOfficialPlayerLink
  PAGE_URL = "https://big6.gr.jp/system/prog/kojinseiseki_career_individual.php?m=pc&p=%s".freeze

  # What a player's page says about them; nil for a graduate's page (the name
  # and school are gone by then), or for an ID that doesn't exist.
  Page = Data.define(:name, :enter_year, :high_school)

  # At most this many pages are read in one call (one box score), a second
  # apart; the rest wait for the next call. A season's first games bring in
  # several dozen new players at once.
  MAX_FETCHES = 30
  REQUEST_INTERVAL = 1

  CACHE_EXPIRY = 30.days

  # Kanji written one way on the league's site and another in Scorebook's
  # 名鑑 (髙橋 and 高橋), besides what NFKC unifies.
  VARIANTS = { "髙" => "高", "﨑" => "崎", "濱" => "浜", "濵" => "浜", "邊" => "辺", "邉" => "辺", "德" => "徳", "櫻" => "桜", "齋" => "斎", "齊" => "斉", "瀨" => "瀬" }.freeze

  def self.link_lineup(game)
    new.link_lineup(game)
  end

  # Links the players of the game's scraped box score (Game#league_official_data,
  # "lineup") whose IDs no player has yet. Returns the players linked.
  def link_lineup(game)
    entries = Array(game.league_official_data&.dig("lineup")).select { |entry| entry["id"].present? }
    known = Player.where(league_official_id: entries.map { |entry| entry["id"] }).pluck(:league_official_id).to_set
    @fetches = 0

    entries.reject { |entry| known.include?(entry["id"]) }.uniq { |entry| entry["id"] }.filter_map do |entry|
      university = entry["side"] == "top" ? game.team0 : game.team1
      link(university, entry["id"])
    end
  end

  # The player of the university whom the ID's page names, now linked to the
  # ID; nil when the page names nobody, or not exactly one player.
  def link(university, id)
    page = page(id) or return nil

    candidates = Player.where(university: university, enter_year: page.enter_year).to_a
      .select { |player| self.class.normalize(player.name) == self.class.normalize(page.name) }
    player = candidates.sole if candidates.one?
    return nil if player.nil? || player.league_official_id.present?

    player.update!(league_official_id: id)
    player
  end

  # A name as the two sites can be compared by: no spaces, and one form of each kanji.
  def self.normalize(name)
    name.to_s.unicode_normalize(:nfkc).gsub(/[[:space:]]/, "").gsub(Regexp.union(VARIANTS.keys), VARIANTS)
  end

  # The player's page, from the cache or else from the league's site (at most
  # MAX_FETCHES a call). A page that couldn't be read isn't cached.
  def page(id)
    key = "league_official_player_page/v1/#{id}"
    return Rails.cache.read(key) if Rails.cache.exist?(key)
    return nil if (@fetches ||= 0) >= MAX_FETCHES

    sleep(REQUEST_INTERVAL) if @fetches.positive?
    @fetches += 1
    html = fetch(format(PAGE_URL, id)) or return nil

    parse(html).tap { |page| Rails.cache.write(key, page, expires_in: CACHE_EXPIRY) }
  end

  # "上田 太陽" in the heading, and "（2023年入学・國學院久我山）" beside it.
  def parse(html)
    doc = Nokogiri::HTML(html)
    name = doc.at_css(".subtitle")&.text.to_s.strip
    match = doc.at_css(".text14px")&.text.to_s.strip&.match(/（(\d{4})年入学・(.*)）/)
    return nil if name.empty? || match.nil?

    Page.new(name: name, enter_year: match[1].to_i, high_school: match[2].presence)
  end

  private

  def fetch(url)
    response = Net::HTTP.get_response(URI(url))
    return response.body.force_encoding(Encoding::UTF_8) if response.is_a?(Net::HTTPSuccess)

    Rails.logger.warn("LeagueOfficialPlayerLink: #{url}: HTTP #{response.code}")
    nil
  rescue StandardError => e
    Rails.logger.warn("LeagueOfficialPlayerLink: #{url}: #{e.class}: #{e.message}")
    nil
  end
end
