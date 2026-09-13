module GamesHelper
  def game_path(game)
    matchup_game_path(game.team0.slug, game.team1.slug, game.season.year, game.season.term, game.game_number)
  end

  def game_ics_path(game)
    matchup_game_path(game.team0.slug, game.team1.slug, game.season.year, game.season.term, game.game_number, format: :ics)
  end

  # Confirmed by spot-checking the league official site: seasons before 2005
  # spring return a page with the game framework but no actual score/box-score
  # data (empty template), so linking to them would be useless.
  LEAGUE_OFFICIAL_MIN_YEAR = 2005

  def league_official_game_url(game)
    return nil if game.season.year < LEAGUE_OFFICIAL_MIN_YEAR

    term_code = game.season.term == "spring" ? "s" : "a"
    vs = "#{game.team0.initial}#{game.team1.initial}#{game.game_number}"

    "https://big6.gr.jp/system/prog/game.php?m=pc&e=league&s=#{game.season.year}#{term_code}" \
      "&gd=#{game.played_on}&gnd=#{game.game_number}&vs=#{vs}"
  end

  def scorebook_game_url(game)
    return nil if game.scorebook_game_id.blank?

    "https://big6scorebook.jp/game/#{game.scorebook_game_id}"
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
