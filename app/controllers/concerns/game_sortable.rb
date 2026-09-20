module GameSortable
  extend ActiveSupport::Concern

  # The columns of the games table that can be sorted by. With no sort in the
  # request the games are in date order, which is the "date" sort ascending.
  SORT_KEYS = %w[season date round card attendance].freeze
  DEFAULT_SORT = "date".freeze

  private

  def apply_game_sort(scope)
    read_game_sort
    direction_sql = @sort_direction == "desc" ? "DESC" : "ASC"

    case @sort
    when "season"
      scope.joins(:season).order(Arel.sql(
        "seasons.year #{direction_sql}, (seasons.term = 'autumn') #{direction_sql}, games.played_on ASC, games.game_number ASC"
      ))
    when "date"
      scope.order(Arel.sql("games.played_on #{direction_sql}, games.game_number #{direction_sql}"))
    when "round"
      scope.order(Arel.sql("games.game_number #{direction_sql}, games.played_on ASC"))
    when "card"
      scope
        .joins("JOIN universities team0_u ON team0_u.id = games.team0_id")
        .joins("JOIN universities team1_u ON team1_u.id = games.team1_id")
        .order(Arel.sql(
          "LEAST(team0_u.position, team1_u.position) #{direction_sql}, " \
          "GREATEST(team0_u.position, team1_u.position) #{direction_sql}, " \
          "games.played_on ASC, games.game_number ASC"
        ))
    when "attendance"
      scope.order(Arel.sql("games.attendance #{direction_sql} NULLS LAST, games.played_on ASC, games.game_number ASC"))
    else
      scope.order(:played_on, :game_number)
    end
  end

  # @sort is nil for a missing or unknown sort, and then the direction is
  # ascending, whatever the request says.
  def read_game_sort
    @sort = SORT_KEYS.include?(params[:sort]) ? params[:sort] : nil
    @sort_direction = @sort && params[:direction] == "desc" ? "desc" : "asc"
  end
end
