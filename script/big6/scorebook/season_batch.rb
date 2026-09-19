# Optional batching for the Scorebook scrapers (season.rb, season_games.rb).
#
# With neither FROM_YEAR nor SEASON_LIMIT set, `pairs` is nil and the scrapers
# behave as usual. Otherwise they scrape only the seasons (year + term, oldest
# first) from FROM_YEAR's spring onward (default: the earliest season), capped
# at SEASON_LIMIT seasons (default: no cap), and ignore the "latest games are
# already final" shortcut — that shortcut would stop a second batch from ever
# running. The range is stateless on purpose: the caller picks the next
# FROM_YEAR, so seasons Scorebook has no data for can't stall the sequence.
#
# Run with: FROM_YEAR=1950 SEASON_LIMIT=10 bin/rails runner script/big6/full_sync.rb
module SeasonBatch
  # Returns [[year, term], ...] for the requested slice, or nil if not batching.
  def self.pairs
    return nil unless ENV["FROM_YEAR"] || ENV["SEASON_LIMIT"]

    from_year = ENV.fetch("FROM_YEAR", 0).to_i
    # "spring" sorts after "autumn" alphabetically, so term: :desc puts spring first.
    seasons = Season.where(year: from_year..).order(year: :asc, term: :desc).pluck(:year, :term)
    ENV["SEASON_LIMIT"] ? seasons.first(ENV["SEASON_LIMIT"].to_i) : seasons
  end
end
