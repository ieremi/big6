require "net/http"
require "uri"
require "json"

url = URI("https://big6scorebook.jp/api/game/search")

(1925..2026).each do |year|
  [ "春", "秋" ].each do |term|
    season = year.to_s + term
    url.query = URI.encode_www_form(
      league: "リーグ戦",
      season: season
    )
    response = Net::HTTP.get_response(url)

    data = JSON.parse(response.body)
    p data.dig("data", 0, "leagueSeason")
  end
end
