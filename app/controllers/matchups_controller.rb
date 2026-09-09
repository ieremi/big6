class MatchupsController < ApplicationController
  def index
    @universities = University.order(:id).to_a
    latest_season = Season.joins(:games).distinct.order(year: :desc, term: :asc).first

    @periods = {
      "5" => { since: 5.years.ago.to_date },
      "10" => { since: 10.years.ago.to_date },
      "20" => { since: 20.years.ago.to_date },
      "all" => {},
      "r" => { season_id: latest_season&.id }
    }
    @matchups = {}

    @universities.combination(2).each do |team0, team1|
      matchup = Matchup.new(team0, team1)
      @matchups[[ team0.id, team1.id ]] = matchup
      @matchups[[ team1.id, team0.id ]] = matchup
    end

    @row_averages = @universities.index_with do |university|
      opponents = @universities - [ university ]

      {
        "rate" => @periods.transform_values do |opts|
          row_average(opponents.filter_map { |o| @matchups[[ university.id, o.id ]].percentage(university, **opts) })
        end,
        "attendance" => {
          "avg" => @periods.transform_values do |opts|
            row_average(opponents.filter_map { |o| @matchups[[ university.id, o.id ]].average_attendance(**opts) })
          end,
          "sum" => @periods.transform_values do |opts|
            row_sum(opponents.filter_map { |o| @matchups[[ university.id, o.id ]].total_attendance(**opts) })
          end
        }
      }
    end
  end

  def show
    team0 = University.find_by!(slug: params[:team0_slug])
    team1 = University.find_by!(slug: params[:team1_slug])
    @matchup = Matchup.new(team0, team1)
  end

  private

  def row_average(values)
    values.empty? ? nil : values.sum / values.size
  end

  def row_sum(values)
    values.empty? ? nil : values.sum
  end
end
