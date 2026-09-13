require "net/http"
require "uri"
require "json"

url = URI("https://big6scorebook.jp/api/game/search")

# Only re-scrape from the latest season we already have games for onward —
# older seasons are final and won't change, so there's no need to refetch
# all ~200 seasons every time. And if every game we know about that should
# already have been played (played_on <= today) is final (both scores
# present), there's nothing new to learn from the source until someone tells
# us a new game happened, so skip entirely. Games scheduled for the future
# are expected to be scoreless and don't count against this check — only
# once their date arrives do they become eligible for it. (Multiple pairs
# can play on the same date, so we check all of them, not just an arbitrary
# "latest" row.)
latest_date = Game.where("played_on <= ?", Date.current).maximum(:played_on)
latest_games = latest_date ? Game.where(played_on: latest_date).includes(:season) : Game.none
latest_game = latest_games.first

if latest_game && latest_games.all? { |g| g.team0_score.present? && g.team1_score.present? }
  puts "All known games on #{latest_date} (#{latest_game.season.title}) are already final; nothing to re-scrape."
else
  start_year = latest_game&.season&.year || Season.minimum(:year) || 1925
  start_term = latest_game&.season&.term || "spring"
  end_year = Season.maximum(:year) || start_year
  term_order = { "spring" => 0, "autumn" => 1 }

  (start_year..end_year).each do |year|
    {
      "春" => "spring",
      "秋" => "autumn"
    }.each do |term_ja, term|
      next if year == start_year && term_order[term] < term_order[start_term]

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
end
