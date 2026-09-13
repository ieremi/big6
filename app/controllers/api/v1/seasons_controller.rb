module Api
  module V1
    class SeasonsController < BaseController
      def index
        seasons = Season.order(year: :desc, term: :desc)
        render json: seasons.map { |s| season_json(s) }
      end

      def show
        season = Season.find_by!(year: params[:year], term: params[:term])
        games = season.games.includes(:team0, :team1, :season).order(:played_on, :game_number)

        render json: season_json(season).merge(games: games.map { |g| game_json(g) })
      end

      def standings
        season = Season.find_by!(year: params[:year], term: params[:term])
        standings = Standings.new(season)

        rows = standings.rows.map do |row|
          {
            university: university_json(row.university),
            wins: row.wins,
            losses: row.losses,
            draws: row.draws,
            points: row.points,
            games: row.games,
            percentage: row.percentage,
            attendance_total: row.attendance_total,
            average_attendance: row.average_attendance
          }
        end

        render json: rows
      end
    end
  end
end
