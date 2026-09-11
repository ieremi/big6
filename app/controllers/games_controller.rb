class GamesController < ApplicationController
  def index
    @universities = University.order(:id).to_a
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
      .sort_by { |opponent, _| opponent.id }
  end

  def matchup_search
    @universities = University.order(:id).to_a

    @matchups = {}
    @universities.combination(2).each do |team0, team1|
      matchup = Matchup.new(team0, team1)
      @matchups[[ team0.id, team1.id ]] = matchup
      @matchups[[ team1.id, team0.id ]] = matchup
    end
  end

  def matchup
    @team0 = University.find_by!(slug: params[:team0_slug])
    @team1 = University.find_by!(slug: params[:team1_slug])
    @matchup = Matchup.new(@team0, @team1)

    if params[:year] && params[:term]
      @season = Season.find_by!(year: params[:year], term: params[:term])
    elsif params[:year]
      @year = params[:year]
    end

    if @season && params[:game_number]
      @game = Game.includes(:team0, :team1, :season)
        .where(team0_id: [ @team0.id, @team1.id ], team1_id: [ @team0.id, @team1.id ])
        .where(season_id: @season.id, game_number: params[:game_number])
        .first!
      @scoreboard = GameScoreboard.new(@game)
      render :show and return
    end

    @games = @matchup.games_for(season: @season, year: @year)
  end
end
