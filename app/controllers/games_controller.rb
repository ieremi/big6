class GamesController < ApplicationController
  def index
    @games = Game.includes(:team0, :team1).order(:played_on, :id)
  end

  def show
    @game = Game.includes(:team0, :team1, :season).find(params[:id])
    @scoreboard = GameScoreboard.new(@game)
  end
end
