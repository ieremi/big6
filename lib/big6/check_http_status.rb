require "net/http"

(2000..2026).each do |year|
  %w[s a].each do |term|
    code = "#{year}#{term}"
    url = URI("https://www.big6.gr.jp/game/league/#{code}/#{code}_schedule.html")

    response = Net::HTTP.get_response(url)

    puts "#{code}: #{response.code}"
  end
end
