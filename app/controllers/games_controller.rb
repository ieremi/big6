class GamesController < ApplicationController
  def index
    @universities = University.order(:position).to_a
    @games_counts = @universities.each_with_object({}) do |u, counts|
      counts[u.id] = Game.where(team0_id: u.id).or(Game.where(team1_id: u.id)).count
    end
  end

  def browse
    @team0 = University.find_by!(slug: params[:team0_slug])

    scope = Game.includes(:team0, :team1, :season)
    scope = scope.where(team0_id: @team0.id).or(scope.where(team1_id: @team0.id))

    if params[:year] && params[:term]
      @season = Season.find_by!(year: params[:year], term: params[:term])
      scope = scope.where(season_id: @season.id)
    elsif params[:year]
      @year = params[:year]
      scope = scope.where(season_id: Season.where(year: @year).select(:id))
    end

    if @season.nil? && @year.nil?
      @games_counts = scope.group(:season_id).count
      @seasons = Season.where(id: @games_counts.keys).order(year: :desc, term: :desc)
      render :team_seasons and return
    end

    @games = scope.order(:played_on, :game_number)
    @games_by_opponent = @games
      .group_by { |g| g.team0_id == @team0.id ? g.team1 : g.team0 }
      .sort_by { |opponent, _| opponent.position }
  end
end
