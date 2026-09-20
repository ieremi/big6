class PlayersController < ApplicationController
  PER_PAGE = 50

  def index
    @universities = University.order(:position)
    @selected_university_ids = Array(params[:university_ids]).map(&:to_i) & @universities.map(&:id)
    search = PlayerSearch.new(
      keyword: params[:q], university_ids: @selected_university_ids.presence,
      start_year: params[:start_year], end_year: params[:end_year], role_group: params[:role], status: params[:status]
    )
    @keyword, @start_year, @end_year, @role_group, @status = search.keyword, search.start_year, search.end_year, search.role_group, search.status

    @total_count = search.players.count
    @last_page = [ (@total_count / PER_PAGE.to_f).ceil, 1 ].max
    @page = params[:page].to_i.clamp(1, @last_page)
    @players = search.ordered.offset((@page - 1) * PER_PAGE).limit(PER_PAGE)
  end

  def show
    @player = Player.includes(:university).find_by!(scorebook_id: params[:id])
    @stats = PlayerStats.new(@player)
    @game_members = @player.game_members.joins(:game)
      .includes(game: [ :season, :team0, :team1 ])
      .order("games.played_on DESC", "games.game_number DESC")
  end

  def og_image
    player = Player.includes(:university).find_by!(scorebook_id: params[:id])

    send_data PlayerOgImage.new(player).to_png, type: "image/png", disposition: "inline"
  end
end
