require "net/http"
require "uri"
require "json"

url = URI("https://big6scorebook.jp/api/game/search")

url.query = URI.encode_www_form(
  league: "リーグ戦",
  season: "1997秋"
)

response = Net::HTTP.get_response(url)

puts response.body
data = JSON.parse(response.body)
