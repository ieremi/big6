require "net/http"
require "uri"
require "json"
require "nokogiri"

# Imports each game's player box score (BattingLine and PitchingLine rows) from
# its Scorebook game page, which embeds every batter and pitcher of both teams
# keyed by Scorebook member id. Only people already imported by PlayerSync are
# kept; anyone else is counted as skipped.
#
# A game's rows are replaced together, so re-running is safe. A game whose page
# can't be fetched, or carries no player stats, keeps whatever rows it had.
# stats_checked_at records a successful fetch (even one with no stats) so a
# backfill can skip games it has already tried.
#
#   bin/rails runner script/big6/import_game_stats.rb
class GameStatsImport
  USER_AGENT = "big6-game-stats/1.0"
  SLEEP_SECONDS = 1

  def self.call(games, sleep_seconds: SLEEP_SECONDS)
    new(games, sleep_seconds: sleep_seconds).call
  end

  def initialize(games, sleep_seconds:)
    @games = games
    @sleep_seconds = sleep_seconds
  end

  # Returns { games:, batting_lines:, pitching_lines:, skipped:, without_stats:, failed: }.
  def call
    player_ids = Player.pluck(:scorebook_id, :id).to_h
    university_ids = university_ids_by_scorebook_team_id
    totals = { games: 0, batting_lines: 0, pitching_lines: 0, skipped: 0, without_stats: 0, failed: 0 }

    @games.each do |game|
      stats = fetch_game_stats(game)
      if stats.nil?
        totals[:failed] += 1
        next
      end

      batting = rows_for(game, stats.values_at("batterTop", "batterBottom").flatten.compact, player_ids, university_ids, totals) { |row| batting_attributes(row) }
      pitching = rows_for(game, stats.values_at("pitcherTop", "pitcherBottom").flatten.compact, player_ids, university_ids, totals) { |row| pitching_attributes(row) }

      if batting.empty? && pitching.empty?
        totals[:without_stats] += 1
      else
        Game.transaction do
          # Not through the game's associations: delete_all would leave them loaded
          # as empty, and a caller still holding this game would see no lines.
          BattingLine.where(game_id: game.id).delete_all
          PitchingLine.where(game_id: game.id).delete_all
          BattingLine.insert_all!(batting) if batting.any?
          PitchingLine.insert_all!(pitching) if pitching.any?
        end
        totals[:games] += 1
        totals[:batting_lines] += batting.size
        totals[:pitching_lines] += pitching.size
      end
      game.update_column(:stats_checked_at, Time.current)
    end

    totals
  end

  private

  def university_ids_by_scorebook_team_id
    ids_by_slug = University.where(slug: ScorebookSync::SCOREBOOK_TEAM_SLUGS.values).pluck(:slug, :id).to_h
    ScorebookSync::SCOREBOOK_TEAM_SLUGS.filter_map { |team_id, slug| [ team_id, ids_by_slug[slug] ] if ids_by_slug[slug] }.to_h
  end

  # Turns Scorebook rows into insertable hashes, one per known player, counting
  # the rest as skipped.
  def rows_for(game, source_rows, player_ids, university_ids, totals)
    rows = source_rows.filter_map do |row|
      player_id = player_ids[row["memberId"]]
      university_id = university_ids[row["teamId"]]
      next unless player_id && university_id

      yield(row).merge(game_id: game.id, player_id: player_id, university_id: university_id, created_at: Time.current, updated_at: Time.current)
    end
    totals[:skipped] += source_rows.size - rows.size
    rows.uniq { |attributes| attributes[:player_id] }
  end

  def batting_attributes(row)
    {
      position: row["position"].presence,
      pa: row["pa"].to_i, ab: row["ab"].to_i, runs: row["rb"].to_i, hits: row["hb"].to_i,
      doubles: row["twob"].to_i, triples: row["threeb"].to_i, home_runs: row["hrb"].to_i, total_bases: row["tb"].to_i,
      rbi: row["rbi"].to_i, strikeouts: row["sob"].to_i, walks: row["bbTotal"].to_i, sacrifices: row["sac"].to_i,
      stolen_bases: row["sb"].to_i, caught_stealing: row["cs"].to_i, gidp: row["gidp"].to_i, fielding_errors: row["error"].to_i
    }
  end

  def pitching_attributes(row)
    {
      batters_faced: row["bf"].to_i, outs: outs_from(row),
      hits: row["hp"].to_i, home_runs: row["hrp"].to_i, walks: row["bbTotalp"].to_i, strikeouts: row["sop"].to_i,
      runs: row["rp"].to_i, earned_runs: row["er"].to_i, pitches: row["np"].to_i,
      started: row["gs"].to_i, complete_game: row["cg"].to_i, shutout: row["sho"].to_i, wins: row["win"].to_i, losses: row["lose"].to_i
    }
  end

  # Outs recorded, from Scorebook's two ways of writing innings pitched: text
  # with the fraction in it ("9 2/3", " 1/3") and ip03 = 0, or whole innings
  # in ip (which may be padded with spaces) with the thirds in ip03. Only one of
  # the two carries the fraction on any row, so the other is ignored.
  def outs_from(row)
    match = row["ip"].to_s.strip.match(%r{\A(\d+)?\s*(?:([12])/3)?\z})
    whole, thirds = match ? [ match[1].to_i, match[2] ] : [ row["ip"].to_i, nil ]
    whole * 3 + (thirds ? thirds.to_i : row["ip03"].to_i)
  end

  # The game page's gameStats hash ({} when the page has none), or nil when the
  # page couldn't be fetched.
  def fetch_game_stats(game)
    uri = URI("https://big6scorebook.jp/game/#{game.scorebook_game_id}")
    response = Net::HTTP.get_response(uri, { "User-Agent" => USER_AGENT })
    sleep(@sleep_seconds)
    return nil unless response.is_a?(Net::HTTPSuccess)

    data = Nokogiri::HTML(response.body).at_css("script#__NEXT_DATA__")&.text
    return nil unless data

    JSON.parse(data).dig("props", "pageProps", "gameStats") || {}
  rescue JSON::ParserError, SocketError, Timeout::Error, SystemCallError
    nil
  end
end
