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

  def browse
    @team0 = University.find_by!(slug: params[:team0_slug])
    @team1 = University.find_by!(slug: params[:team1_slug]) if params[:team1_slug]

    scope = Game.includes(:team0, :team1, :season)
    scope = if @team1
      scope.where(team0_id: [ @team0.id, @team1.id ], team1_id: [ @team0.id, @team1.id ])
    else
      scope.where(team0_id: @team0.id).or(scope.where(team1_id: @team0.id))
    end

    if params[:year] && params[:term]
      @season = Season.find_by!(year: params[:year], term: params[:term])
      scope = scope.where(season_id: @season.id)
    elsif params[:year]
      @year = params[:year]
      scope = scope.where(season_id: Season.where(year: @year).select(:id))
    end

    if @season && params[:game_number]
      @game = scope.find_by!(game_number: params[:game_number])
      @scoreboard = GameScoreboard.new(@game)
      render :show and return
    end

    @games = scope.order(:played_on, :game_number)
  end
end
