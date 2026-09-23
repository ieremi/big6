module PlayersHelper
  ROLE_GROUP_LABELS = {
    "player" => "選手",
    "manager" => "マネージャー",
    "staff" => "監督・コーチ・部長",
    "other" => "その他（学生コーチ・アナリストなど）"
  }.freeze

  def hands_label(player)
    player.hands_label
  end

  def enrollment_label(status)
    case status
    when Player::ACTIVE_ENROLLMENT_STATUS then "現役"
    when Player::ALUMNI_ENROLLMENT_STATUS then "卒業生"
    end
  end

  def players_page_path(page)
    players_path(request.query_parameters.merge("page" => page))
  end

  # A link that narrows the players list to exactly this value of a column
  # (high school, faculty, role, or position — param is whichever query
  # parameter PlayerSearch reads it from), keeping whatever filters are
  # already active: a click in the table drills further into the current
  # search, and one on a player's own page (which carries no filters of its
  # own) starts a fresh one. Plain text, not a link, when there's nothing to
  # filter by.
  def player_filter_link(value, param)
    return value if value.blank?

    link_to value, players_path(request.query_parameters.except("page").merge(param => value))
  end

  # Same idea, but narrows to exactly this entry year (both ends of the
  # range) rather than "from this year on".
  def player_enter_year_link(enter_year)
    return "—" unless enter_year

    link_to enter_year, players_path(request.query_parameters.except("page").merge(start_year: enter_year, end_year: enter_year))
  end

  # The player's game page, from the point of view of the game they were on the roster for.
  def player_game_path(game)
    matchup_game_path(game.team0.slug, game.team1.slug, game.season.year, game.season.term, game.game_number)
  end

  # ".257" style, "1.000" for a perfect average, "---" when there was no at-bat.
  def batting_average_label(average)
    return "---" if average.nil?

    format("%.3f", average).sub(/\A0(?=\.)/, "")
  end

  # OPS is written like a batting average: ".763", or "1.024" above 1.
  def ops_label(ops)
    batting_average_label(ops)
  end

  # Innings pitched from outs: 10 outs is "3 1/3".
  def innings_label(outs)
    PitchingLine.innings_label(outs)
  end

  def era_label(era)
    era.nil? ? "---" : format("%.2f", era)
  end

  # The short name of the team the player's own team faced in this line's game.
  def opponent_name(line)
    game = line.game
    (game.team0_id == line.university_id ? game.team1 : game.team0).short_name
  end

  # The columns of the sortable tables on the player page: heading => [shortcut,
  # direction of the first click]. Batting columns have capital shortcuts and
  # pitching columns lower-case ones. A column that two tables have (the season
  # and the game-by-game table) has one shortcut, which sorts both; the date and
  # opponent shortcuts are shared by every table on the page.
  BATTING_COLUMNS = {
    "シーズン" => [ "D", "desc" ], "日付" => [ "D", "desc" ], "相手" => [ "V", "asc" ],
    "打率" => [ "A", "desc" ], "OPS" => [ "O", "desc" ], "試合" => [ "G", "desc" ], "打席" => [ "P", "desc" ], "打数" => [ "B", "desc" ],
    "安打" => [ "H", "desc" ], "二塁打" => [ "N", "desc" ], "三塁打" => [ "E", "desc" ], "本塁打" => [ "M", "desc" ], "打点" => [ "I", "desc" ],
    "得点" => [ "R", "desc" ], "三振" => [ "K", "desc" ], "四死球" => [ "W", "desc" ], "犠打・犠飛" => [ "C", "desc" ], "盗塁" => [ "S", "desc" ],
    "併殺打" => [ "L", "desc" ], "失策" => [ "F", "desc" ]
  }.freeze

  PITCHING_COLUMNS = {
    "シーズン" => [ "D", "desc" ], "日付" => [ "D", "desc" ], "相手" => [ "V", "asc" ],
    "防御率" => [ "e", "asc" ], "登板" => [ "g", "desc" ], "先発" => [ "s", "desc" ], "完投" => [ "c", "desc" ], "完封" => [ "x", "desc" ],
    "勝" => [ "w", "desc" ], "敗" => [ "l", "desc" ], "結果" => [ "y", "asc" ], "投球回" => [ "i", "desc" ], "打者" => [ "t", "desc" ],
    "球数" => [ "p", "desc" ], "被安打" => [ "h", "desc" ], "被本塁打" => [ "m", "desc" ], "奪三振" => [ "k", "desc" ], "与四死球" => [ "b", "desc" ],
    "失点" => [ "r", "desc" ], "自責点" => [ "a", "desc" ]
  }.freeze

  BENCH_COLUMNS = {
    "日付" => [ "D", "asc" ], "試合" => [ "V", "asc" ], "背番号" => [ "U", "asc" ], "学年" => [ "Y", "asc" ],
    "役割" => [ "T", "asc" ], "打順" => [ "Q", "asc" ], "守備" => [ "Z", "asc" ]
  }.freeze

  # The roster on a university page: the same shortcuts as the players page.
  ROSTER_COLUMNS = {
    "入学年" => [ "Y", "desc" ], "氏名" => [ "N", "asc" ], "役割" => [ "O", "asc" ],
    "位置" => [ "P", "asc" ], "投打" => [ "B", "asc" ], "出身高校" => [ "S", "asc" ]
  }.freeze

  HEADING_TITLES = { "OPS" => "出塁率＋長打率" }.freeze

  # The headings for these columns (labels of one of the column tables above), in order.
  def sortable_headers(columns, *labels)
    safe_join(labels.map do |label|
      shortcut, first = columns.fetch(label)
      sortable_column_header(label, shortcut, first: first, title: HEADING_TITLES[label])
    end)
  end

  # Scorebook writes the positions of a batting line in kanji for older games
  # ("[三]", "打一") and in codes for newer ones ("[4]", "H"): the scorecard's
  # numbers, D for the designated hitter, H for a pinch hitter and R for a pinch
  # runner. Brackets mark a starter. Shown in kanji either way.
  POSITION_CODES = LeagueOfficialGameScraper::POSITION_KANJI.merge("H" => "打", "R" => "走").freeze

  def batting_positions_label(position)
    position.to_s.gsub(/[1-9DHR]/) { |code| POSITION_CODES.fetch(code) }
  end

  # Season rows sort in time order: 1997 spring, then autumn.
  def season_sort_value(season)
    season.year + (season.term == "autumn" ? 0.5 : 0)
  end

  # A pitching line's result sorts wins first, then losses, then none.
  def pitching_result_sort_value(line)
    line.wins.positive? ? 0 : (line.losses.positive? ? 1 : nil)
  end
end
