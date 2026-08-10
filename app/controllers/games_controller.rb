class GamesController < ApplicationController
  def index
    @games = Game.includes(:team0, :team1).order(:played_on, :id)
  end
end
