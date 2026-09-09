class SeasonsController < ApplicationController
  def index
    @seasons = Season.order(year: :desc, term: :asc)
    @games_counts = Game.group(:season_id).count
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
