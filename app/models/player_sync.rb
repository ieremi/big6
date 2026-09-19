require "net/http"
require "uri"
require "json"

# Imports Scorebook's member roster (名鑑) into Player. Members are upserted by
# their Scorebook id, so re-running only adds new people and refreshes existing
# ones; nothing is deleted.
#
# Scorebook's member API returns 20 members per page and reports whether there
# is a next page. It covers every entry year back to 1872, though older years
# carry little more than a name. Some staff (部長, 監督, ...) have no entry year
# and so never show up when filtering by year; call_undated finds them by
# sweeping the whole unfiltered list.
#
#   bin/rails runner script/big6/import_players.rb
class PlayerSync
  API_URL = URI("https://big6scorebook.jp/api/member/search")
  USER_AGENT = "big6-player-sync/1.0"

  FIRST_YEAR = 1872
  SLEEP_SECONDS = 1
  MAX_PAGES = 2_000

  def self.call(from_year: FIRST_YEAR, to_year: Date.current.year, sleep_seconds: SLEEP_SECONDS)
    new(from_year: from_year, to_year: to_year, sleep_seconds: sleep_seconds).call
  end

  def self.call_undated(sleep_seconds: SLEEP_SECONDS)
    new(from_year: nil, to_year: nil, sleep_seconds: sleep_seconds).call_undated
  end

  def initialize(from_year:, to_year:, sleep_seconds:)
    @from_year = from_year
    @to_year = to_year
    @sleep_seconds = sleep_seconds
  end

  # Imports the members of each entry year in the range. Returns
  # { imported:, skipped: }; skipped counts members Scorebook lists for a team
  # we don't have (or without a name).
  def call
    totals = { imported: 0, skipped: 0 }

    (@from_year..@to_year).each do |year|
      each_page_of_members(year) { |members| import(members, totals) }
    end

    totals
  end

  # Imports only the members that have no entry year, found by paging through
  # every member (about 670 pages, so about ten minutes at one request a second).
  def call_undated
    totals = { imported: 0, skipped: 0 }
    each_page_of_members(nil) { |members| import(members.select { |member| member["enterYearWest"].nil? }, totals) }
    totals
  end

  private

  def import(members, totals)
    rows = members.filter_map { |member| row_for(member) }
    totals[:skipped] += members.size - rows.size
    return if rows.empty?

    Player.upsert_all(rows, unique_by: :scorebook_id)
    totals[:imported] += rows.size
  end

  def university_id_by_scorebook_team_id
    @university_id_by_scorebook_team_id ||= begin
      ids_by_slug = University.where(slug: ScorebookSync::SCOREBOOK_TEAM_SLUGS.values).pluck(:slug, :id).to_h
      ScorebookSync::SCOREBOOK_TEAM_SLUGS.filter_map { |team_id, slug| [ team_id, ids_by_slug[slug] ] if ids_by_slug[slug] }.to_h
    end
  end

  # year nil means no entry-year filter: every member, oldest id first.
  def each_page_of_members(year)
    page = 1
    loop do
      response = fetch_page(year, page)
      yield response["members"] || []
      break unless response["hasNextPage"]

      page += 1
      raise "Scorebook member API: more than #{MAX_PAGES} pages (#{year || 'unfiltered'})" if page > MAX_PAGES
    end
  end

  def row_for(member)
    university_id = university_id_by_scorebook_team_id[member["teamId"]]
    return nil unless university_id && member["nameFull"].present?

    {
      scorebook_id: member["id"],
      university_id: university_id,
      name: member["nameFull"],
      name_kana: [ member["nameFamilyKana"], member["nameFirstKana"] ].compact_blank.join(" ").presence,
      enter_year: member["enterYearWest"],
      role: member["teamPositon"].presence,
      position: member["playerPosition"].presence,
      batting_hand: member["battingHand"].presence,
      pitching_hand: member["pitchingHand"].presence,
      high_school: member["highSchool"].presence,
      faculty: member["univDiv"].presence,
      grade: member["gradeN"],
      enrollment_status: member["enrollmentActive"]
    }
  end

  def fetch_page(year, page)
    uri = API_URL.dup
    params = { page: page }
    params[:enter_year_west] = year if year
    uri.query = URI.encode_www_form(params)

    response = Net::HTTP.get_response(uri, { "User-Agent" => USER_AGENT })
    raise "Scorebook member API: HTTP #{response.code} for #{year || 'unfiltered'} page #{page}" unless response.is_a?(Net::HTTPSuccess)

    sleep(@sleep_seconds)
    JSON.parse(response.body)
  end
end
