require "net/http"
require "nokogiri"
require "json"

url = URI("https://big6scorebook.jp/game?season=1938%E6%98%A5&league=%E3%83%AA%E3%83%BC%E3%82%B0%E6%88%A6")

html = Net::HTTP.get(url)
doc = Nokogiri::HTML(html)
doc.css("a").each do |a|
  puts "#{a.text.strip} => #{a["href"]}"
end
