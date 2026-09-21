module Api
  module V1
    class BaseController < ActionController::API
      rescue_from ActiveRecord::RecordNotFound do
        render json: { error: "not found" }, status: :not_found
      end

      private

      # nil (any university) unless university[] is given; slugs that match no
      # university leave nobody, as the games search does.
      def university_ids_from_params
        return nil if params[:university].blank?

        University.where(slug: Array(params[:university])).pluck(:id)
      end

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

      # team0/team1 carry just a university slug (not a full embedded
      # object) plus that team's own score — the same 6 universities repeat
      # across every game, so fetch /api/v1/universities once and look them
      # up by slug for name/color/etc.
      def game_json(game, include_season: true, include_id: true)
        json = {
          id: game.id,
          season: season_json(game.season),
          played_on: game.played_on,
          round: game.game_number,
          team0: { slug: game.team0.slug, score: game.team0_score },
          team1: { slug: game.team1.slug, score: game.team1_score },
          attendance: game.attendance,
          status: game.game_status,
          cancelled: game.not_held?
        }
        json.delete(:season) unless include_season
        json.delete(:id) unless include_id
        json
      end

      # Identifies a game the same way GET /api/v1/games/:year/:term/:team0/:team1/:round does,
      # instead of exposing our internal database id.
      def game_ref_json(game)
        {
          year: game.season.year,
          term: game.season.term,
          team0: game.team0.slug,
          team1: game.team1.slug,
          round: game.game_number
        }
      end
    end
  end
end
