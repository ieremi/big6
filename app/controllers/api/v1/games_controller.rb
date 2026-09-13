module Api
  module V1
    class GamesController < BaseController
      PER_PAGE = 100

      def index
        scope = Game.includes(:team0, :team1, :season)

        if params[:university].present?
          university_ids = University.where(slug: Array(params[:university])).pluck(:id)
          scope = scope.where(team0_id: university_ids).or(scope.where(team1_id: university_ids))
        end

        scope = scope.where(season_id: Season.where(term: Array(params[:term])).select(:id)) if params[:term].present?
        scope = scope.where("played_on >= ?", Date.new(params[:start_year].to_i, 1, 1)) if params[:start_year].present?
        scope = scope.where("played_on <= ?", Date.new(params[:end_year].to_i, 12, 31)) if params[:end_year].present?

        total = scope.count
        page = [ params[:page].to_i, 1 ].max
        games = scope.order(:played_on, :game_number).offset((page - 1) * PER_PAGE).limit(PER_PAGE)

        render json: {
          total: total,
          page: page,
          per_page: PER_PAGE,
          games: games.map { |g| game_json(g) }
        }
      end

      def show
        game = Game.includes(:team0, :team1, :season).find(params[:id])
        scoreboard = GameScoreboard.new(game)

        render json: game_json(game).merge(scoreboard: scoreboard_json(scoreboard))
      end

      private

      def scoreboard_json(scoreboard)
        return nil unless scoreboard.present?

        {
          stadium: scoreboard.stadium,
          innings: scoreboard.innings.index_with { |n| { top: scoreboard.top_runs(n), bottom: scoreboard.bottom_runs(n) } },
          hits: { top: scoreboard.top_hits, bottom: scoreboard.bottom_hits },
          errors: { top: scoreboard.top_errors, bottom: scoreboard.bottom_errors },
          started_at: scoreboard.started_at,
          finished_at: scoreboard.finished_at,
          duration_minutes: scoreboard.duration_minutes,
          umpires: scoreboard.umpires
        }
      end
    end
  end
end
