module Api
  module V1
    class SeasonsController < BaseController
      def index
        seasons = Season.newest_first
        render json: seasons.map { |s| season_json(s) }
      end

      def show
        season = Season.find_by!(year: params[:year], term: params[:term])
        games = season.games.includes(:team0, :team1, :season).order(:played_on, :game_number)

        render json: season_json(season).merge(og_image_url: api_v1_season_og_image_url(season.year, season.term), games: games.map { |g| game_json(g, include_season: false, include_id: false) })
      end

      # The same image the season page uses for og:image; label is an optional subtitle.
      def og_image
        season = Season.find_by!(year: params[:year], term: params[:term])

        send_data OgImages.season(season, label: params[:label]), type: "image/png", disposition: "inline"
      end

      def standings
        season = Season.find_by!(year: params[:year], term: params[:term])
        return render(json: printed_standings_json(season)) if season.source_standings
        # Only one club's games and no printed table: no standings to give.
        return render(json: []) if season.from_printed_sources?

        standings = Standings.new(season)
        team_stats = TeamStats.new(season).rows.index_by(&:university)

        rows = standings.rows.map do |row|
          {
            university: university_json(row.university),
            rank: row.rank,
            wins: row.wins,
            losses: row.losses,
            draws: row.draws,
            points: row.points,
            games: row.games,
            percentage: row.percentage,
            runs_scored: row.runs_scored,
            runs_allowed: row.runs_allowed,
            attendance_total: row.total_attendance(weekends_only: weekends_only_from_params),
            average_attendance: row.average_attendance(weekends_only: weekends_only_from_params),
            team_stats: team_stats_json(team_stats[row.university])
          }
        end

        render json: rows
      end

      private

      # A university's チーム成績 (TeamStats) from the box scores, or nil with none.
      def team_stats_json(row)
        return nil unless row

        { games: row.games, batting_average: row.batting.average, home_runs: row.batting.home_runs,
          stolen_bases: row.batting.stolen_bases, era: row.pitching.era, fielding_errors: row.batting.fielding_errors }
      end

      # A season taken from a club's history has only that club's games, so its
      # rows are the printed 勝敗表 (Season#source_standings), in the printed
      # order, with the figures the table has and the source; runs and
      # attendance aren't known.
      def printed_standings_json(season)
        table = season.source_standings
        universities = University.where(slug: table["rows"].map { |row| row["university"] }).index_by(&:slug)
        table["rows"].map do |row|
          {
            university: university_json(universities.fetch(row["university"])),
            wins: row["wins"],
            losses: row["losses"],
            draws: row["draws"],
            points: row["points"],
            games: row["games"],
            percentage: row["average"].to_f,
            runs_scored: nil,
            runs_allowed: nil,
            attendance_total: nil,
            average_attendance: nil,
            source: { citation: table["citation"], url: table["url"] }
          }
        end
      end
    end
  end
end
