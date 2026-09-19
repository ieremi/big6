# Regenerates the static reference data shown on season pages:
#
#   db/reference/prime_ministers.yml  - Prime Ministers of Japan (Wikidata)
#   db/reference/gdp_per_capita.yml   - Japan GDP per capita, current US$ (World Bank NY.GDP.PCAP.CD)
#
# Re-run it when a Prime Minister changes (the incumbent's term is open-ended
# until then) or when the World Bank publishes another year.
#
# Run with: ruby script/big6/update_reference_data.rb
require "date"
require "json"
require "net/http"
require "uri"
require "yaml"

OUTPUT_DIR = File.expand_path("../../db/reference", __dir__)
USER_AGENT = "big6-reference-data/1.0"

# Seasons start in 1925, so drop terms that ended before then.
FIRST_DATE = Date.new(1925, 1, 1)

# Wikidata lists these as holders of the office, but they were acting
# (臨時代理) rather than appointed Prime Minister.
NOT_PRIME_MINISTERS = [ "伊東正義" ].freeze

def get_json(url)
  uri = URI(url)
  response = Net::HTTP.get_response(uri, { "User-Agent" => USER_AGENT, "Accept" => "application/json" })
  raise "#{uri.host}: HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

  JSON.parse(response.body)
end

# Wikidata records one statement per cabinet, so the same person shows up as
# several consecutive terms; merge those into one.
def prime_minister_terms
  query = <<~SPARQL
    SELECT ?pmLabel ?start ?end WHERE {
      ?pm p:P39 ?st .
      ?st ps:P39 wd:Q274948 ; pq:P580 ?start .
      OPTIONAL { ?st pq:P582 ?end }
      SERVICE wikibase:label { bd:serviceParam wikibase:language "ja,en". }
    }
    ORDER BY ?start
  SPARQL
  rows = get_json("https://query.wikidata.org/sparql?format=json&query=#{URI.encode_www_form_component(query)}")
    .dig("results", "bindings")
    .map do |row|
      {
        "name" => row.dig("pmLabel", "value"),
        "start_on" => Date.iso8601(row.dig("start", "value")[0, 10]),
        "end_on" => (row["end"] ? Date.iso8601(row.dig("end", "value")[0, 10]) : nil)
      }
    end
  rows = rows.uniq.reject { |row| NOT_PRIME_MINISTERS.include?(row["name"]) }.sort_by { |row| row["start_on"] }

  merged = rows.each_with_object([]) do |row, terms|
    last = terms.last
    if last && last["name"] == row["name"] && last["end_on"] && (row["start_on"] - last["end_on"]).abs <= 1
      last["end_on"] = row["end_on"]
    else
      terms << row.dup
    end
  end

  merged.select { |term| term["end_on"].nil? || term["end_on"] >= FIRST_DATE }
end

def gdp_per_capita_by_year
  url = "https://api.worldbank.org/v2/country/JPN/indicator/NY.GDP.PCAP.CD?format=json&per_page=200&date=1960:#{Date.today.year}"
  get_json(url)[1]
    .select { |row| row["value"] }
    .to_h { |row| [ row["date"].to_i, row["value"].round ] }
    .sort.to_h
end

def write_yaml(name, header, data)
  path = File.join(OUTPUT_DIR, name)
  File.write(path, "#{header.lines.map { |line| "# #{line}".rstrip }.join("\n")}\n#{YAML.dump(data).delete_prefix("---\n")}")
  puts "wrote #{path}"
end

Dir.mkdir(OUTPUT_DIR) unless Dir.exist?(OUTPUT_DIR)

terms = prime_minister_terms
write_yaml("prime_ministers.yml", <<~HEADER, terms)
  Prime Ministers of Japan, one entry per continuous term.
  Source: Wikidata (office Q274948), merged by script/big6/update_reference_data.rb.
  A term covers start_on <= date < end_on; end_on is empty for the incumbent.
HEADER

gdp = gdp_per_capita_by_year
write_yaml("gdp_per_capita.yml", <<~HEADER, gdp)
  Japan GDP per capita (current US$), by calendar year.
  Source: World Bank indicator NY.GDP.PCAP.CD, via script/big6/update_reference_data.rb.
  Years the World Bank has not published yet are simply absent.
HEADER

puts "#{terms.size} terms (#{terms.last['name']} incumbent: #{terms.last['end_on'].nil?}), GDP #{gdp.keys.first}-#{gdp.keys.last}"
