require "net/http"
require "uri"
require "nokogiri"

# Scrapes the official league site's season schedule page
# (big6.gr.jp/game/league/<year><term>/<year><term>_schedule.html) and
# creates any Game rows listed there that we don't have yet. This is mainly
# how a newly-added decisive third game (3回戦) gets picked up — it isn't on
# the schedule until the first two games of a series have split 1-1, so
# there's nothing to import until the league site adds the row.
#
# The page's markup mixes encodings (team names are Shift_JIS, the rest of
# the page is UTF-8), a quirk of the source site, not our fetching — see
# SJIS_FIXES.
class LeagueOfficialScheduleScraper
  SJIS_FIXES = {
    "\x91\x81".b => "早".b,
    "\x8c\x63".b => "慶".b,
    "\x96\xbe".b => "明".b,
    "\x96\x40".b => "法".b,
    "\x93\x8c".b => "東".b,
    "\x97\xa7".b => "立".b
  }.freeze

  TEAM_NAME_TO_SLUG = {
    "早大" => "waseda",
    "慶大" => "keio",
    "明大" => "meiji",
    "法大" => "hosei",
    "東大" => "tokyo",
    "立大" => "rikkio"
  }.freeze

  def self.call(season)
    new(season).call
  end

  def initialize(season)
    @season = season
  end

  def call
    doc = fetch_doc
    return [] unless doc

    parse(doc).filter_map { |entry| import(entry) }
  end

  private

  def fetch_doc
    return nil if @season.year < 2005

    term_code = @season.term == "spring" ? "s" : "a"
    url = "https://big6.gr.jp/game/league/#{@season.year}#{term_code}/#{@season.year}#{term_code}_schedule.html"

    response = Net::HTTP.get_response(URI(url))
    return nil unless response.is_a?(Net::HTTPSuccess)

    raw = response.body.dup.force_encoding("ASCII-8BIT")
    SJIS_FIXES.each { |bad, good| raw.gsub!(bad, good) }
    Nokogiri::HTML(raw.force_encoding("UTF-8"))
  end

  # When a day hosts two different pairings (the common case — Jingu can only
  # host one game at a time), only the first game's start time is published
  # on the schedule; the second is assumed to follow this long after, same
  # heuristic as EstimatedGameSchedule's own doubleheader assumption.
  GAME_INTERVAL_MINUTES = 180 # 3h

  def parse(doc)
    doc.css("td.scd_date").flat_map do |date_cell|
      match = date_cell.text.strip.match(%r{(\d{1,2})/(\d{1,2})})
      next [] unless match

      date = Date.new(@season.year, match[1].to_i, match[2].to_i)
      row = date_cell.ancestors("tr").first
      next [] unless row

      time_text = row.at_css("td.text13px")&.text&.strip
      published_time = time_text && time_text[/\d{1,2}:\d{2}/]

      row.css("div.content_left").each_with_index.filter_map do |game_div, index|
        cells = game_div.css("td.scd_vs")
        next if cells.size < 3

        team_a = TEAM_NAME_TO_SLUG[cells[0].text.strip]
        team_b = TEAM_NAME_TO_SLUG[cells[2].text.strip]
        next unless team_a && team_b

        start_time = published_time && add_minutes(published_time, GAME_INTERVAL_MINUTES * index)
        { date: date, team_a: team_a, team_b: team_b, start_time: start_time }
      end
    end
  end

  def import(entry)
    team_a = University.find_by(slug: entry[:team_a])
    team_b = University.find_by(slug: entry[:team_b])
    return nil unless team_a && team_b

    scope = Game.where(season: @season)
      .where(team0_id: [ team_a.id, team_b.id ], team1_id: [ team_a.id, team_b.id ])
    return nil if scope.exists?(played_on: entry[:date])

    Game.create!(
      season: @season,
      team0: team_a,
      team1: team_b,
      played_on: entry[:date],
      game_number: scope.count + 1,
      league_official_data: { "scheduledStartTime" => entry[:start_time] }.compact
    )
  end

  def add_minutes(hhmm, minutes)
    hour, min = hhmm.split(":").map(&:to_i)
    total = (hour * 60 + min + minutes) % (24 * 60)
    format("%02d:%02d", total / 60, total % 60)
  end
end
