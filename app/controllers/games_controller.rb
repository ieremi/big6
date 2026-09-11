class GamesController < ApplicationController
  include GameSortable

  PER_PAGE = 50

  def index
    @universities = University.order(:position).to_a
    @searched = params[:filtered].present?

    if @searched
      @selected_university_ids = Array(params[:university_ids]).map(&:to_i)
      @selected_terms = Array(params[:terms])
    else
      @selected_university_ids = []
      @selected_terms = []
    end

    @start_year = params[:start_year].presence
    @end_year = params[:end_year].presence

    return unless @searched

    scope = Game.includes(:team0, :team1, :season)
    scope = scope.where(team0_id: @selected_university_ids).or(scope.where(team1_id: @selected_university_ids))
    scope = scope.where(season_id: Season.where(term: @selected_terms).select(:id))
    scope = scope.where("played_on >= ?", Date.new(@start_year.to_i, 1, 1)) if @start_year.present?
    scope = scope.where("played_on <= ?", Date.new(@end_year.to_i, 12, 31)) if @end_year.present?

    @total_count = scope.count
    @page = [ params[:page].to_i, 1 ].max
    @games = apply_game_sort(scope).offset((@page - 1) * PER_PAGE).limit(PER_PAGE)
    @total_pages = (@total_count.to_f / PER_PAGE).ceil
    @range_start = @total_count.zero? ? 0 : (@page - 1) * PER_PAGE + 1
    @range_end = [ @page * PER_PAGE, @total_count ].min
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

    @games = apply_game_sort(scope)
    @games_by_opponent = @games
      .group_by { |g| g.team0_id == @team0.id ? g.team1 : g.team0 }
      .sort_by { |opponent, _| opponent.position }
  end

  def og_image
    team0 = University.find_by!(slug: params[:team0_slug])
    team1 = University.find_by!(slug: params[:team1_slug])
    season = Season.find_by!(year: params[:year], term: params[:term])
    game = Game.includes(:team0, :team1, :season)
      .where(team0_id: [ team0.id, team1.id ], team1_id: [ team0.id, team1.id ])
      .where(season_id: season.id, game_number: params[:game_number])
      .first!

    send_data GameOgImage.new(game).to_png, type: "image/png", disposition: "inline"
  end

  def index_og_image
    send_data SiteOgImage.new(title: "Game Search").to_png, type: "image/png", disposition: "inline"
  end

  def team_og_image
    team = University.find_by!(slug: params[:team0_slug])
    subtitle = if params[:year] && params[:term]
      "#{params[:year]} #{params[:term].capitalize}"
    else
      "All Seasons"
    end

    send_data TeamOgImage.new(team, subtitle: subtitle).to_png, type: "image/png", disposition: "inline"
  end
end
