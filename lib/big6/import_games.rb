require "net/http"
require "nokogiri"
require "date"

schedule_url =
  "https://www.big6.gr.jp/game/league/2026s/2026s_schedule.html"

html = Net::HTTP.get(URI(schedule_url))
doc = Nokogiri::HTML(html)

season = Season.find_by!(year: 2026, term: "spring")

game_tables = doc.css("table")[3..38]

game_urls = game_tables.filter_map do |table|
  href = table.css("a").first&.[]("href")
  next unless href

  URI.join(schedule_url, href)
end

game_urls.each do |url|
  game_html = Net::HTTP.get(url)
  game_doc = Nokogiri::HTML(game_html)

  card = game_doc.at_css(".gamescore-card").text.strip
  game_number = game_doc.at_css(".gamescore-gamename").text.to_i

  game_info = game_doc.at_css(".gamescore-gameinfo")
  text = game_info.text.strip

  match = text.match(/(\d+)月(\d+)日/)
  month = match[1].to_i
  day = match[2].to_i

  played_on = Date.new(2026, month, day)

  team0_name, team1_name = card.split(" - ")

  team0 = University.find_by!(short_name: team0_name)
  team1 = University.find_by!(short_name: team1_name)

  score_table = game_doc.css("table")[16]
  rows = score_table.css("tr")

  team0_score = rows[0].css("th, td").last.text.strip.to_i
  team1_score = rows[2].css("th, td").last.text.strip.to_i
  game = Game.find_or_initialize_by(
    season: season,
    team0: team0,
    team1: team1,
    played_on: played_on,
    game_number: game_number
  )

game.team0_score = team0_score
game.team1_score = team1_score
game.save!
end
