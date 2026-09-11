module GameSortable
  extend ActiveSupport::Concern

  SORT_KEYS = %w[season card].freeze

  private

  def apply_game_sort(scope)
    @sort = SORT_KEYS.include?(params[:sort]) ? params[:sort] : nil
    @sort_direction = params[:direction] == "desc" ? "desc" : "asc"
    direction_sql = @sort_direction == "desc" ? "DESC" : "ASC"

    case @sort
    when "season"
      scope.joins(:season).order(Arel.sql(
        "seasons.year #{direction_sql}, (seasons.term = 'autumn') #{direction_sql}, games.played_on ASC, games.game_number ASC"
      ))
    when "card"
      scope
        .joins("JOIN universities team0_u ON team0_u.id = games.team0_id")
        .joins("JOIN universities team1_u ON team1_u.id = games.team1_id")
        .order(Arel.sql(
          "LEAST(team0_u.position, team1_u.position) #{direction_sql}, " \
          "GREATEST(team0_u.position, team1_u.position) #{direction_sql}, " \
          "games.played_on ASC, games.game_number ASC"
        ))
    else
      scope.order(:played_on, :game_number)
    end
  end
end
