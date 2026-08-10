require "net/http"
require "nokogiri"
require "json"

url = URI("https://big6scorebook.jp/game/1983100402")
html = Net::HTTP.get(url)
doc = Nokogiri::HTML(html)



data = JSON.parse(doc.at_css("#__NEXT_DATA__").text)
game_info = data.dig("props", "pageProps", "gameInfo")
game_stats = data.dig("props", "pageProps", "gameStats")
