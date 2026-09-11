module GamesHelper
  def game_path(game)
    matchup_game_path(game.team0.slug, game.team1.slug, game.season.year, game.season.term, game.game_number)
  end

  def sortable_game_header(key, label, shortcut)
    active = @sort == key
    th_classes = [ "sortable" ]
    th_classes << (@sort_direction == "asc" ? "sorted-asc" : "sorted-desc") if active

    next_direction = (active && @sort_direction == "asc") ? "desc" : "asc"
    query = request.query_parameters.except("page").merge(sort: key, direction: next_direction)
    url = "#{request.path}?#{query.to_query}"

    content_tag :th, class: th_classes.join(" ") do
      link_to url, data: { shortcut: shortcut, shortcut_label: "#{label}でソート" } do
        safe_join([ label, " ", content_tag(:kbd, shortcut) ])
      end
    end
  end
end
