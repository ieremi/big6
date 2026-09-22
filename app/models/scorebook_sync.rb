require "net/http"
require "uri"
require "json"

# Refreshes a single season's box-score data from Scorebook and updates the
# matching Game rows. Used by SyncTodaysGamesJob to poll for a game's full
# detail (innings, duration, etc.) while it's in progress. For bulk/historical
# imports across many seasons, see script/big6/scorebook/season_games.rb and
# script/big6/game.rb instead.
#
# A "中止"/"ノーゲーム" entry (see Game::NOT_HELD_STATUSES) is a game of its own,
# with that status and no round number (Game.record_cancellation): the game we
# already have for it is marked, or one is added. A game listed as scheduled would
# otherwise stay "試合前" for good.
#
# The entries made for the replay of a cancelled game can carry the wrong round
# label (Scorebook has called the replay of a 2回戦 "1回戦"). So once a pair has
# had a game cancelled in the season, a label for a round number the pair has
# already played isn't trusted: the game gets the next number instead. (Before
# then, and in other pairs, a repeated label is left alone, as in the old
# seasons where a round was replayed under its own number, and a playoff, which
# is a series of its own.)
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

  # members: false leaves the bench members alone, which is a whole season's
  # import: for refreshing a game's scoreboard while it is played.
  def self.call(season, members: true)
    new(season).call(members: members)
  end

  def initialize(season)
    @season = season
  end

  # Records the games that weren't held (中止, ノーゲーム) from the Scorebook data
  # already stored on the season, fetching nothing: those we have are marked, and
  # those we don't are added. This finds the games left over from before cancelled
  # entries were imported, which have no result and no status and so look as if they
  # were still to be played. A game Scorebook has as finished is left alone.
  # Returns the games newly marked or added.
  def record_stored_cancellations
    universities_by_slug = University.where(slug: SCOREBOOK_TEAM_SLUGS.values).index_by(&:slug)

    Array(@season.scorebook_games).filter_map do |info|
      next if info["topTeamId"].nil? || info["bottomTeamId"].nil?
      next unless Game::NOT_HELD_STATUSES.include?(info["gameStatus"])

      teams = [ info["topTeamId"], info["bottomTeamId"] ].map { |id| universities_by_slug.fetch(SCOREBOOK_TEAM_SLUGS.fetch(id)) }
      game = record_cancellation(info, teams, unless_finished: true)
      game if game && (game.previously_new_record? || game.saved_change_to_game_status?)
    end
  end

  def call(members: true)
    scorebook_games = fetch_scorebook_games
    return if scorebook_games.blank?

    @season.update!(scorebook_games: scorebook_games)
    import_games(scorebook_games)
    GameMemberImport.call(Season.where(id: @season.id)) if members
  end

  private

  def fetch_scorebook_games
    uri = API_URL.dup
    uri.query = URI.encode_www_form(league: "リーグ戦", season: "#{@season.year}#{TERM_JA.fetch(@season.term)}")

    response = Net::HTTP.get_response(uri)
    return nil unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)["data"]
  end

  def record_cancellation(info, teams, **options)
    Game.record_cancellation(
      season: @season, teams: teams, played_on: Date.parse(info.fetch("gameDay")),
      scorebook_game_id: info["id"], status: info["gameStatus"], **options,
      attributes: { game_order: info["gameOrder"], counted_in_stats: info["isCounted"] != false }
    )
  end

  def import_games(scorebook_games)
    universities_by_slug = University.where(slug: SCOREBOOK_TEAM_SLUGS.values).index_by(&:slug)
    pair_round_counts = Hash.new(0)
    numbers_used = Hash.new { |hash, key| hash[key] = [] }
    pairs_with_cancellation = Set.new

    scorebook_games.sort_by { |info| [ info["gameDay"].to_s, info["gameOrder"].to_i ] }.each do |info|
      next if info["topTeamId"].nil? || info["bottomTeamId"].nil?

      team0 = universities_by_slug.fetch(SCOREBOOK_TEAM_SLUGS.fetch(info.fetch("topTeamId")))
      team1 = universities_by_slug.fetch(SCOREBOOK_TEAM_SLUGS.fetch(info.fetch("bottomTeamId")))

      pair_key = [ team0.id, team1.id ].sort
      counted = info["isCounted"] != false # false for a playoff

      if Game::NOT_HELD_STATUSES.include?(info["gameStatus"])
        pairs_with_cancellation << pair_key if counted
        record_cancellation(info, [ team0, team1 ])
        next
      end

      match = info["round"].to_s.match(/(\d+)回戦/)
      game_number = match ? match[1].to_i : pair_round_counts[pair_key] + 1
      game_number = numbers_used[pair_key].max + 1 if counted && pairs_with_cancellation.include?(pair_key) && numbers_used[pair_key].include?(game_number)
      numbers_used[pair_key] << game_number if counted
      pair_round_counts[pair_key] = game_number

      game = Game.find_or_initialize_by(
        season: @season,
        team0: team0,
        team1: team1,
        played_on: Date.parse(info.fetch("gameDay"))
      )

      attendance = info["attendance"].to_s.delete(",").strip

      game.game_number = game_number
      # As with game_status below: Scorebook reporting nothing yet (still
      # blank) shouldn't erase a score the league site's box score already
      # provisionally filled in — only an actual value from Scorebook (once
      # it catches up) overwrites what's there.
      game.team0_score = info["runsTotalTop"]&.to_i || game.team0_score
      game.team1_score = info["runsTotalBottom"]&.to_i || game.team1_score
      game.scorebook_game_id = info["id"]
      game.game_order = info["gameOrder"]
      # Some other source (the league site's box score, most often — see
      # LeagueOfficialGameScraper) may already have this game further along
      # (cancelled, in progress, finished) than Scorebook's own gameStatus
      # reports it: Scorebook can lag behind a game actually starting, the
      # same way it can lag behind one being called off. Don't let a stale
      # "試合前" from Scorebook undo whichever further-along status is
      # already recorded — only a game we still have as scheduled can be
      # (re)assigned "試合前" here.
      status = Game.status_for(info["gameStatus"], team0_score: game.team0_score, team1_score: game.team1_score, played_on: game.played_on)
      game.game_status = status unless status == Game::PENDING_STATUS && !game.scheduled?
      game.counted_in_stats = info["isCounted"] != false
      game.duration_minutes = GameScoreboard.parse_duration_minutes(info["gameTimeNet"])
      game.attendance = attendance.to_i if attendance.match?(/\A\d+\z/)
      game.save!
    end
  end
end
