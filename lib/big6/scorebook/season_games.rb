require "net/http"
require "uri"
require "json"

url = URI("https://big6scorebook.jp/api/game/search")

(1925..2026).each do |year|
  {
    "春" => "spring",
    "秋" => "autumn"
  }.each do |term_ja, term|
    url.query = URI.encode_www_form(
      league: "リーグ戦",
      season: "#{year}#{term_ja}"
    )

    response = Net::HTTP.get_response(url)

    unless response.is_a?(Net::HTTPSuccess)
      warn "#{year}#{term_ja}: HTTP #{response.code}"
      next
    end

    data = JSON.parse(response.body)
    scorebook_games = data.dig("data")
    if scorebook_games.blank?
      puts "#{year}#{term_ja}: no data"
      next
    end

    season = Season.find_by(
      year: year,
      term: term
    )

    unless season
      warn "#{year}#{term_ja}: Season not found"
      next
    end

    season.update!(
      scorebook_games: scorebook_games
    )
  end
end
