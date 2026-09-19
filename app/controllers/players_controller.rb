class PlayersController < ApplicationController
  PER_PAGE = 50

  def index
    @universities = University.order(:position)
    @keyword = params[:q].to_s.strip.presence
    @selected_university_ids = Array(params[:university_ids]).map(&:to_i) & @universities.map(&:id)
    @start_year = params[:start_year].presence&.to_i
    @end_year = params[:end_year].presence&.to_i
    @role_group = (Player::ROLE_GROUPS.keys + [ "other" ]).include?(params[:role]) ? params[:role] : nil
    @status = %w[active alumni].include?(params[:status]) ? params[:status] : nil

    players = filtered_players
    @total_count = players.count
    @last_page = [ (@total_count / PER_PAGE.to_f).ceil, 1 ].max
    @page = params[:page].to_i.clamp(1, @last_page)
    @players = players.joins(:university).preload(:university)
      .order(Arel.sql("players.enter_year DESC NULLS LAST"), "universities.position", "players.name")
      .offset((@page - 1) * PER_PAGE).limit(PER_PAGE)
  end

  def show
    @player = Player.includes(:university).find_by!(scorebook_id: params[:id])
    @game_members = @player.game_members.joins(:game)
      .includes(game: [ :season, :team0, :team1 ])
      .order("games.played_on DESC", "games.game_number DESC")
  end

  private

  def filtered_players
    players = Player.all
    players = players.matching_keyword(@keyword) if @keyword
    players = players.where(university_id: @selected_university_ids) if @selected_university_ids.any?
    players = players.where(players: { enter_year: @start_year.. }) if @start_year
    players = players.where(players: { enter_year: ..@end_year }) if @end_year
    players = players.in_role_group(@role_group) if @role_group
    players = players.where(enrollment_status: status_value) if @status
    players
  end

  def status_value
    { "active" => Player::ACTIVE_ENROLLMENT_STATUS, "alumni" => Player::ALUMNI_ENROLLMENT_STATUS }.fetch(@status)
  end
end
