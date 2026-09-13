module Api
  module V1
    class MatchupsController < BaseController
      def show
        team0 = University.find_by!(slug: params[:team0_slug])
        team1 = University.find_by!(slug: params[:team1_slug])
        matchup = Matchup.new(team0, team1)

        opts = {}
        opts[:since] = params[:since_years].to_i.years.ago.to_date if params[:since_years].present?
        if params[:year].present? && params[:term].present?
          season = Season.find_by(year: params[:year], term: params[:term])
          opts[:season_id] = season&.id
        end

        render json: {
          team0: university_json(team0),
          team1: university_json(team1),
          wins: { team0.slug => matchup.wins(team0, **opts), team1.slug => matchup.wins(team1, **opts) },
          draws: matchup.draws(**opts),
          percentage: { team0.slug => matchup.percentage(team0, **opts), team1.slug => matchup.percentage(team1, **opts) },
          attendance: {
            average: matchup.average_attendance(**opts),
            total: matchup.total_attendance(**opts)
          },
          duration_minutes: {
            average: matchup.average_duration_minutes(**opts),
            total: matchup.total_duration_minutes(**opts),
            max: matchup.max_duration_minutes(**opts),
            min: matchup.min_duration_minutes(**opts),
            stddev: matchup.duration_stddev_minutes(**opts)
          }
        }
      end
    end
  end
end
