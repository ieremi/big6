require "net/http"
require "uri"
require "json"

# Refreshes the reference data shown on season pages:
#
#   PrimeMinisterTerm  - Prime Ministers of Japan (Wikidata)
#   GdpPerCapitaYear   - Japan GDP per capita, current US$ (World Bank NY.GDP.PCAP.CD)
#
# Run it when a Prime Minister changes (the incumbent's term is open-ended
# until then) or when the World Bank publishes another year:
#
#   bin/rails runner script/big6/update_reference_data.rb
#
# Both tables are replaced in one transaction, and only after everything has
# been fetched, so a failed request leaves the existing data untouched.
class ReferenceDataSync
  USER_AGENT = "big6-reference-data/1.0"

  # Seasons start in 1925, so drop terms that ended before then.
  FIRST_DATE = Date.new(1925, 1, 1)

  # Wikidata lists these as holders of the office, but they were acting
  # (臨時代理) rather than appointed Prime Minister.
  NOT_PRIME_MINISTERS = [ "伊東正義" ].freeze

  PRIME_MINISTERS_QUERY = <<~SPARQL
    SELECT ?pmLabel ?start ?end WHERE {
      ?pm p:P39 ?st .
      ?st ps:P39 wd:Q274948 ; pq:P580 ?start .
      OPTIONAL { ?st pq:P582 ?end }
      SERVICE wikibase:label { bd:serviceParam wikibase:language "ja,en". }
    }
    ORDER BY ?start
  SPARQL

  def self.call
    new.call
  end

  # Wikidata records one statement per cabinet, so the same person shows up as
  # several consecutive terms; merge those into one. rows are
  # { name:, start_on:, end_on: } hashes, in any order.
  def self.build_terms(rows)
    rows = rows.uniq.reject { |row| NOT_PRIME_MINISTERS.include?(row[:name]) }.sort_by { |row| row[:start_on] }

    merged = rows.each_with_object([]) do |row, terms|
      last = terms.last
      if last && last[:name] == row[:name] && last[:end_on] && (row[:start_on] - last[:end_on]).abs <= 1
        last[:end_on] = row[:end_on]
      else
        terms << row.dup
      end
    end

    merged.select { |term| term[:end_on].nil? || term[:end_on] >= FIRST_DATE }
  end

  def call
    terms = self.class.build_terms(fetch_prime_minister_rows)
    gdp_by_year = fetch_gdp_by_year
    raise "No Prime Minister terms fetched; keeping the existing data" if terms.empty?
    raise "No GDP per capita figures fetched; keeping the existing data" if gdp_by_year.empty?

    ApplicationRecord.transaction do
      PrimeMinisterTerm.delete_all
      PrimeMinisterTerm.insert_all!(terms)
      GdpPerCapitaYear.delete_all
      GdpPerCapitaYear.insert_all!(gdp_by_year.map { |year, usd| { year: year, usd: usd } })
    end

    { prime_minister_terms: terms.size, gdp_years: gdp_by_year.keys.minmax }
  end

  private

  def fetch_prime_minister_rows
    url = "https://query.wikidata.org/sparql?format=json&query=#{URI.encode_www_form_component(PRIME_MINISTERS_QUERY)}"
    get_json(url).dig("results", "bindings").map do |row|
      {
        name: row.dig("pmLabel", "value"),
        start_on: Date.iso8601(row.dig("start", "value")[0, 10]),
        end_on: (row["end"] ? Date.iso8601(row.dig("end", "value")[0, 10]) : nil)
      }
    end
  end

  def fetch_gdp_by_year
    url = "https://api.worldbank.org/v2/country/JPN/indicator/NY.GDP.PCAP.CD?format=json&per_page=200&date=1960:#{Date.current.year}"
    get_json(url)[1]
      .select { |row| row["value"] }
      .to_h { |row| [ row["date"].to_i, row["value"].round ] }
  end

  def get_json(url)
    uri = URI(url)
    response = Net::HTTP.get_response(uri, { "User-Agent" => USER_AGENT, "Accept" => "application/json" })
    raise "#{uri.host}: HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  end
end
