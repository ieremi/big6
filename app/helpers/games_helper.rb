module GamesHelper
  def game_path(game)
    game_browse_path(game.team0.slug, game.team1.slug, game.season.year, game.season.term, game.game_number)
  end

  def games_sort_link(column, label)
    active = @sort == column
    next_direction = active && @direction == "asc" ? "desc" : "asc"

    link_to games_path(request.query_parameters.merge(sort: column, direction: next_direction)) do
      active ? "#{label} #{@direction == 'asc' ? '▲' : '▼'}" : label
    end
  end
end
