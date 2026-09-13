require "net/http"
require "uri"
require "json"

# Refreshes a single season's box-score data from Scorebook and updates the
# matching Game rows. Used by SyncTodaysGamesJob to poll for a game's full
# detail (innings, duration, etc.) while it's in progress. For bulk/historical
# imports across many seasons, see script/big6/scorebook/season_games.rb and
# script/big6/game.rb instead.
class ScorebookSync
  API_URL = URI("https://big6scorebook.jp/api/game/search")

  SCOREBOOK_TEAM_SLUGS = {
    1 => "waseda",
    2 => "keio",
    3 => "meiji",
    4 => "hosei",
    5 => "tokyo",
    6 => "rikkio"
  }.freeze

  TERM_JA = { "spring" => "春", "autumn" => "秋" }.freeze

  def self.call(season)
    new(season).call
  end

  def initialize(season)
    @season = season
  end

  def call
    scorebook_games = fetch_scorebook_games
    return if scorebook_games.blank?

    @season.update!(scorebook_games: scorebook_games)
    import_games(scorebook_games)
  end

  private

  def fetch_scorebook_games
    uri = API_URL.dup
    uri.query = URI.encode_www_form(league: "リーグ戦", season: "#{@season.year}#{TERM_JA.fetch(@season.term)}")

    response = Net::HTTP.get_response(uri)
    return nil unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)["data"]
  end

  def import_games(scorebook_games)
    universities_by_slug = University.where(slug: SCOREBOOK_TEAM_SLUGS.values).index_by(&:slug)
    pair_round_counts = Hash.new(0)

    scorebook_games.each do |info|
      next if info["topTeamId"].nil? || info["bottomTeamId"].nil?

      team0 = universities_by_slug.fetch(SCOREBOOK_TEAM_SLUGS.fetch(info.fetch("topTeamId")))
      team1 = universities_by_slug.fetch(SCOREBOOK_TEAM_SLUGS.fetch(info.fetch("bottomTeamId")))

      pair_key = [ team0.id, team1.id ].sort
      match = info["round"].to_s.match(/(\d+)回戦/)
      game_number = match ? match[1].to_i : pair_round_counts[pair_key] + 1
      pair_round_counts[pair_key] = game_number

      game = Game.find_or_initialize_by(
        season: @season,
        team0: team0,
        team1: team1,
        played_on: Date.parse(info.fetch("gameDay"))
      )

      attendance = info["attendance"].to_s.delete(",").strip

      game.game_number = game_number
      game.team0_score = info["runsTotalTop"]&.to_i
      game.team1_score = info["runsTotalBottom"]&.to_i
      game.scorebook_game_id = info["id"]
      game.attendance = attendance.to_i if attendance.match?(/\A\d+\z/)
      game.save!
    end
  end
end
