class GamesController < ApplicationController
  SORT_COLUMNS = {
    "played_on" => :played_on,
    "game_number" => :game_number
  }.freeze

  def index
    @games = Game.includes(:team0, :team1)
    @games = @games.where(season_id: params[:season_id]) if params[:season_id].present?

    if params[:university_id].present?
      @games = @games.where(team0_id: params[:university_id]).or(@games.where(team1_id: params[:university_id]))
    end

    @games = @games.where(game_number: params[:game_number]) if params[:game_number].present?

    @sort = SORT_COLUMNS.key?(params[:sort]) ? params[:sort] : "played_on"
    @direction = params[:direction] == "desc" ? "desc" : "asc"
    @games = @games.order(SORT_COLUMNS[@sort] => @direction.to_sym).order(:id)

    @universities = University.order(:id)
    @seasons = Season.order(year: :desc, term: :asc)
  end

  def show
    @game = Game.includes(:team0, :team1, :season).find(params[:id])
    @scoreboard = GameScoreboard.new(@game)
  end
end
