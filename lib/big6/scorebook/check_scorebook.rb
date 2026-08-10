require "net/http"
require "uri"
require "nokogiri"

(1926..2026).each do |year|
  [ "春", "秋" ].each do |term|
    params = {
      season: year.to_s + term,
      league: "リーグ戦"
    }
    url = URI("https://big6scorebook.jp/game")
    url.query = URI.encode_www_form(params)

    response = Net::HTTP.get_response(url)
    html = Net::HTTP.get(url)
    doc = Nokogiri::HTML(html)
    puts "#{params}: #{response.code}, #{html.bytesize}, #{doc.css(".game-result-heading").count}"
  end
end
