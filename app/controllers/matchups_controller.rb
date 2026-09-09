class MatchupsController < ApplicationController
  PERIODS = {
    "5" => -> { 5.years.ago.to_date },
    "10" => -> { 10.years.ago.to_date },
    "20" => -> { 20.years.ago.to_date },
    "all" => -> { nil }
  }.freeze

  def index
    @universities = University.order(:id).to_a
    @periods = PERIODS.transform_values(&:call)
    @matchups = {}

    @universities.combination(2).each do |team0, team1|
      matchup = Matchup.new(team0, team1)
      @matchups[[ team0.id, team1.id ]] = matchup
      @matchups[[ team1.id, team0.id ]] = matchup
    end
  end

  def show
    team0 = University.find_by!(slug: params[:team0_slug])
    team1 = University.find_by!(slug: params[:team1_slug])
    @matchup = Matchup.new(team0, team1)
  end
end
