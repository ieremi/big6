require "net/http"
require "nokogiri"
require "date"

schedule_url =
  "https://www.big6.gr.jp/game/league/2000s/2000s_schedule.html"

html = Net::HTTP.get(URI(schedule_url))
doc = Nokogiri::HTML(html)

schedule_table = doc.css("table")[2]

game_urls = schedule_table.css("a").filter_map do |a|
  href = a["href"]

  next unless href
  next unless href.match?(/\A2000s_[a-z]+\d+\.html\z/i)

  URI.join(schedule_url, href)
end

season = Season.find_by!(year: 2000, term: "spring")

game_urls.each do |game_url|
  game_html = Net::HTTP.get(game_url)
  game_doc = Nokogiri::HTML(game_html)

  header =
    game_doc.css("table")[0].text.gsub(/\p{Space}+/, " ").strip

  match = header.match(
    /(.+?)\s*-\s*(.+?)\s+(\d+)回戦\s+(\d+)月(\d+)日/
  )

unless match
  puts "FAILED: #{game_url}"
  puts header[0, 200]
  next
end
  team0_name = match[1].gsub(/\p{Space}+/, "")
  team1_name = match[2].gsub(/\p{Space}+/, "")

  game_number = match[3].to_i
  month = match[4].to_i
  day = match[5].to_i

  score_table = game_doc.css("table")[2]
  rows = score_table.css("tr")

  team0_cells = rows[1].css("th, td")
  team1_cells = rows[2].css("th, td")

  team0_score = team0_cells.last.text.strip.to_i
  team1_score = team1_cells.last.text.strip.to_i

  played_on = Date.new(2000, month, day)

  team0 = University.find_by!(short_name: team0_name)
  team1 = University.find_by!(short_name: team1_name)

  game = Game.find_or_initialize_by(
    season: season,
    played_on: played_on,
    team0: team0,
    team1: team1,
    game_number: game_number
  )

  game.team0_score = team0_score
  game.team1_score = team1_score

  game.save!
end
