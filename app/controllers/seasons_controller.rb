class SeasonsController < ApplicationController
  def index
    @seasons = Season.order(year: :desc, term: :asc)
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
    @season = Season.find(params[:id])
    @games = @season.games.includes(:team0, :team1).order(:played_on, :game_number)
  end

  def standings
    @season = Season.find(params[:id])
    @standings = Standings.new(@season)
  end
end
