class SeasonsController < ApplicationController
  def index
    @seasons = Season.order(year: :desc, term: :desc)
    @games_counts = Game.group(:season_id).count
    @attendance_totals = @seasons.each_with_object({}) do |season, totals|
      next if season.scorebook_games.blank?

      total = season.scorebook_games.sum do |g|
        value = g["attendance"].to_s.delete(",").strip
        value.match?(/\A\d+\z/) ? value.to_i : 0
      end
      totals[season.id] = total if total.positive?
    end
  end

  def show
    @season = Season.find_by!(year: params[:year], term: params[:term])
    @games = @season.games.includes(:team0, :team1).order(:played_on, :game_number)
    @weeks = SeasonWeeks.new(@games).weeks
  end

  def standings
    @season = Season.find_by!(year: params[:year], term: params[:term])
    @standings = Standings.new(@season)
  end
end
