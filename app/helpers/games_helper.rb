module GamesHelper
  def games_sort_link(column, label)
    active = @sort == column
    next_direction = active && @direction == "asc" ? "desc" : "asc"

    link_to games_path(request.query_parameters.merge(sort: column, direction: next_direction)) do
      active ? "#{label} #{@direction == 'asc' ? '▲' : '▼'}" : label
    end
  end
end
