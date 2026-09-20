module Api
  module V1
    class UniversitiesController < BaseController
      def index
        universities = University.order(:position)
        render json: universities.map { |u| university_json(u) }
      end

      def show
        university = University.find_by!(slug: params[:slug])
        record = TeamRecord.new(university)

        render json: university_json(university).merge(
          og_image_url: api_v1_university_og_image_url(university.slug),
          record: {
            wins: record.wins,
            losses: record.losses,
            draws: record.draws,
            percentage: record.percentage,
            longest_streak: streak_json(record.longest_streak),
            current_streak: streak_json(record.current_streak)
          }
        )
      end

      # The same image the university page uses for og:image.
      def og_image
        send_data OgImages.university(University.find_by!(slug: params[:slug])), type: "image/png", disposition: "inline"
      end

      private

      def streak_json(streak)
        return nil if streak.nil?

        { length: streak.length, first_game: game_ref_json(streak.first_game), last_game: game_ref_json(streak.last_game) }
      end
    end
  end
end
