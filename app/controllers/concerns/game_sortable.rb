module GameSortable
  extend ActiveSupport::Concern

  # The columns of the games table that can be sorted by. With no sort in the
  # request the games are in date order, which is the "date" sort ascending.
  SORT_KEYS = %w[season date round card attendance].freeze
  DEFAULT_SORT = "date".freeze
  DEFAULT_KEY = SortOrder::Key.new(DEFAULT_SORT, "asc")

  private

  # Up to SortOrder::MAX_KEYS columns, each breaking the ties of the ones before
  # it, then date order.
  def apply_game_sort(scope)
    read_game_sort

    scope = scope.joins(:season) if @sort_order.columns.include?("season")
    if @sort_order.columns.include?("card")
      scope = scope
        .joins("JOIN universities team0_u ON team0_u.id = games.team0_id")
        .joins("JOIN universities team1_u ON team1_u.id = games.team1_id")
    end

    order = @sort_order.flat_map { |key| game_sort_expressions(key.column, key.sql_direction) }
    scope.order(Arel.sql([ *order, "games.played_on ASC", "games.game_number ASC" ].join(", ")))
  end

  def game_sort_expressions(column, direction)
    case column
    when "season" then [ "seasons.year #{direction}", "(seasons.term = 'autumn') #{direction}" ]
    when "date" then [ "games.played_on #{direction}", "games.game_number #{direction} NULLS LAST" ]
    when "round" then [ "games.game_number #{direction} NULLS LAST" ]
    when "card"
      [ "LEAST(team0_u.position, team1_u.position) #{direction}", "GREATEST(team0_u.position, team1_u.position) #{direction}" ]
    when "attendance" then [ "games.attendance #{direction} NULLS LAST" ]
    end
  end

  # @sort_order is empty for a missing or unknown sort, and the games are then
  # in date order.
  def read_game_sort
    @sort_order = SortOrder.from_params(params[:sort], params[:direction], columns: SORT_KEYS)
  end
end
