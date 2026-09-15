require "net/http"
require "uri"
require "nokogiri"

# Scrapes the JMA's (気象庁) historical daily weather data for Tokyo
# (prec_no=44, block_no=47662 — the Otemachi/東京 station) and stores the
# daytime weather description and high/low temperature on each Game played
# that day. One request per (year, month) covers every game played that
# month, since every known Big6 stadium (see StadiumLocation) is in central
# Tokyo — there's no need to look up a station per stadium.
#
# Older records (roughly pre-1930s) only have temperature; the weather
# description cell is genuinely blank on JMA's own page, not a scraping gap.
class JmaWeatherScraper
  PREC_NO = 44
  BLOCK_NO = 47662

  DAY_COLUMN = 0
  TEMP_HIGH_COLUMN = 7
  TEMP_LOW_COLUMN = 8
  DAYTIME_SUMMARY_COLUMN = 19
  EXPECTED_COLUMNS = 21

  def self.call(year, month)
    new(year, month).call
  end

  def initialize(year, month)
    @year = year
    @month = month
  end

  def call
    doc = fetch_doc
    return [] unless doc

    parse(doc).flat_map { |day, weather| apply(day, weather) }
  end

  private

  def fetch_doc
    url = "https://www.data.jma.go.jp/stats/etrn/view/daily_s1.php" \
      "?prec_no=#{PREC_NO}&block_no=#{BLOCK_NO}&year=#{@year}&month=#{@month}&day=&view=p1"

    response = Net::HTTP.get_response(URI(url))
    return nil unless response.is_a?(Net::HTTPSuccess)

    Nokogiri::HTML(response.body.dup.force_encoding("UTF-8"))
  end

  def parse(doc)
    table = doc.at_css("#tablefix1")
    return {} unless table

    # First 3 rows are the (nested) header.
    table.css("tr")[3..].to_a.filter_map do |row|
      cells = row.css("th,td").map { |c| c.text.strip }
      next if cells.size < EXPECTED_COLUMNS

      day = cells[DAY_COLUMN].to_i
      next unless Date.valid_date?(@year, @month, day)

      [ day, { summary: cells[DAYTIME_SUMMARY_COLUMN].presence, temp_high: to_f(cells[TEMP_HIGH_COLUMN]), temp_low: to_f(cells[TEMP_LOW_COLUMN]) } ]
    end.to_h
  end

  def to_f(text)
    Float(text)
  rescue ArgumentError, TypeError
    nil
  end

  def apply(day, weather)
    return [] if weather[:summary].blank? && weather[:temp_high].nil? && weather[:temp_low].nil?

    date = Date.new(@year, @month, day)
    Game.where(played_on: date).filter_map do |game|
      changed = game.weather_summary != weather[:summary] || game.temp_high != weather[:temp_high] || game.temp_low != weather[:temp_low]
      next unless changed

      game.update!(weather_summary: weather[:summary], temp_high: weather[:temp_high], temp_low: weather[:temp_low])
      game
    end
  end
end
