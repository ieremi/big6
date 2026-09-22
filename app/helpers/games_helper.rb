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

  # The columns of a game's bench tables: heading => [shortcut, direction of the
  # first click]. The same shortcuts as the bench table on a player's page; both
  # teams' tables share them, so one key sorts both.
  GAME_BENCH_COLUMNS = {
    "背番号" => [ "U", "asc" ], "氏名" => [ "N", "asc" ], "学年" => [ "Y", "desc" ],
    "役割" => [ "T", "asc" ], "打順" => [ "Q", "asc" ], "守備" => [ "Z", "asc" ], "出場" => [ "P", "asc" ]
  }.freeze

  # Fielding positions in their scorecard order (投 1, 捕 2, ... 右 9, then 指).
  FIELDING_ORDER = LeagueOfficialGameScraper::POSITION_KANJI.values.freeze

  # A bench member's role sorts staff first (most senior first), then players by
  # their position (投手, 捕手, 一塁手 ...), then anyone else (マネージャー, 学生コーチ ...).
  def bench_role_sort_value(role)
    return nil if role.blank?

    staff = Player::STAFF_ROLES.index(role)
    return staff if staff

    position = PlayerSearch::POSITION_ORDER.index(role)
    position ? Player::STAFF_ROLES.size + position : Player::STAFF_ROLES.size + PlayerSearch::POSITION_ORDER.size
  end

  def fielding_position_sort_value(position)
    position.presence && (FIELDING_ORDER.index(position) || FIELDING_ORDER.size)
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

  # "12試合", or "12試合（ほか中止1）" when the list has cancelled games. A cancelled
  # game is in the list but isn't a game that was held, so it isn't counted as one.
  def games_count_label(games)
    list = games.to_a
    cancelled = list.count(&:not_held?)
    label = "#{list.size - cancelled}試合"
    cancelled.positive? ? "#{label}（ほか中止#{cancelled}）" : label
  end

  # "2回戦", or "—" for a game with no round number (one that wasn't held).
  def round_label(game)
    game.game_number ? "#{game.game_number}回戦" : "—"
  end

  # A game's teams and score as a link to its page. A cancelled game is plain
  # text instead: there is nothing to see on its page, and its round number is
  # usually its replay's too, so the page would be the replay's.
  def game_matchup_link(game)
    label = safe_join([
      game.team0.short_name, " ",
      score_span(game.team0_score, game.team1_score, played_on: game.played_on, status: game.status_label), " ",
      game.team1.short_name
    ])

    game.not_held? ? tag.span(label, class: "game-cancelled") : link_to(label, game_path(game))
  end

  # A column heading that sorts the games table by it (see GameSortable). The
  # games are in date order when nothing is asked for, so the date column counts
  # as sorted then.
  def sortable_game_header(key, label, shortcut, first: "asc")
    sortable_link_header(key, label, shortcut, sort: @sort || GameSortable::DEFAULT_SORT, direction: @sort_direction, first: first)
  end
end
