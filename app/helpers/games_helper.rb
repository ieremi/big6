module GamesHelper
  def game_path(game)
    matchup_game_path(game.team0.slug, game.team1.slug, game.season.year, game.season.term, game.game_number)
  end

  def game_ics_path(game)
    matchup_game_path(game.team0.slug, game.team1.slug, game.season.year, game.season.term, game.game_number, format: :ics)
  end

  def game_ics_url(game)
    matchup_game_url(game.team0.slug, game.team1.slug, game.season.year, game.season.term, game.game_number, format: :ics)
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

  # A column heading that sorts the games table by it (see GameSortable). The
  # games are in date order when nothing is asked for, so the date column counts
  # as sorted then.
  def sortable_game_header(key, label, shortcut, first: "asc")
    sortable_link_header(key, label, shortcut, sort: @sort || GameSortable::DEFAULT_SORT, direction: @sort_direction, first: first)
  end
end
