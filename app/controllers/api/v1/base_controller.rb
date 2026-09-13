module Api
  module V1
    class BaseController < ActionController::API
      rescue_from ActiveRecord::RecordNotFound do
        render json: { error: "not found" }, status: :not_found
      end

      private

      def university_json(university)
        {
          slug: university.slug,
          name: university.name,
          short_name: university.short_name,
          initial: university.initial,
          color: university.color,
          position: university.position
        }
      end

      def season_json(season)
        { year: season.year, term: season.term, title: season.title }
      end

      def game_json(game)
        {
          id: game.id,
          season: season_json(game.season),
          played_on: game.played_on,
          game_number: game.game_number,
          team0: university_json(game.team0),
          team1: university_json(game.team1),
          team0_score: game.team0_score,
          team1_score: game.team1_score,
          attendance: game.attendance
        }
      end
    end
  end
end
