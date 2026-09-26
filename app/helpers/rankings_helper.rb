module RankingsHelper
  # The parameters of the minimum: what it is, and the default it was shown beside.
  MINIMUM_PARAMS = %w[minimum default_minimum].freeze

  KIND_LABELS = { "batting" => "打者", "pitching" => "投手" }.freeze

  # The table's columns, left to right: [sort key, heading]. The keys are the
  # ones PlayerRanking::SORT_KEYS and the Web API use.
  COLUMNS = {
    "batting" => [
      [ "rank", "順位" ], [ "player", "選手" ], [ "university", "大学" ], [ "ops", "OPS" ], [ "average", "打率" ], [ "obp", "出塁率" ],
      [ "slg", "長打率" ], [ "games", "試合" ], [ "pa", "打席" ], [ "ab", "打数" ], [ "hits", "安打" ], [ "home_runs", "本塁打" ]
    ],
    "pitching" => [
      [ "rank", "順位" ], [ "player", "選手" ], [ "university", "大学" ], [ "era", "防御率" ], [ "games", "登板" ], [ "outs", "投球回" ],
      [ "wins", "勝" ], [ "losses", "敗" ], [ "hits", "被安打" ], [ "strikeouts", "奪三振" ], [ "walks", "与四死球" ], [ "earned_runs", "自責点" ]
    ]
  }.freeze

  # "2017年春季以降", "通算" or "2026年春季": the period a ranking is over.
  def ranking_period_title
    case @period
    when :season then @season.title
    when :complete then "#{@since.title}以降"
    else "通算"
    end
  end

  # Seasons as runs of consecutive ones: "1925年春季〜1976年秋季", "2010年春季〜2011年秋季".
  def season_ranges(seasons)
    runs = seasons.slice_when { |a, b| next_season_key(a) != [ b.year, b.term ] }
    runs.map { |run| run.size == 1 ? run.first.title : "#{run.first.title}〜#{run.last.title}" }
  end

  # The seasons of the player's four years that have no per-game stats (titles),
  # for a career ranking: his totals are short of them. [] without an entry year.
  def ranking_missing_seasons(player)
    return [] unless player.enter_year

    @missing_season_titles ||= @missing_seasons.to_h { |season| [ [ season.year, season.term ], season.title ] }
    PlayerRanking.career_seasons(player.enter_year).filter_map { |key| @missing_season_titles[key] }
  end

  # "打席" for batters, "投球回" for pitchers: what a ranking's volume is counted in.
  def ranking_unit(kind)
    kind == "batting" ? "打席" : "投球回"
  end

  # "打者" / "投手".
  def ranking_noun(kind)
    kind == "batting" ? "打者" : "投手"
  end

  # "40打席以上の打者" / "10投球回以上の投手", or "打席のある打者すべて" with no minimum: who is ranked.
  def ranking_target_label(kind, minimum)
    return "#{ranking_unit(kind)}のある#{ranking_noun(kind)}すべて" if minimum.zero?

    "#{minimum}#{ranking_unit(kind)}以上の#{ranking_noun(kind)}"
  end

  # The ranking's own URL for another page, keeping the filters and the sort.
  def rankings_page_path(page)
    ranking_path(@kind, rankings_filter_params.merge(rankings_sort_params).merge("page" => page))
  end

  # The other kind of ranking with the same filters (the period is dropped by the
  # controller if the other kind has no stats for it). Its sort starts over, since
  # the other kind has other columns.
  # The minimum isn't kept: it is counted in plate appearances for one and in innings for the other.
  def rankings_kind_path(kind)
    ranking_path(kind, rankings_filter_params.except(*MINIMUM_PARAMS))
  end

  # A column heading that sorts the table by it: a click on the column it is
  # already sorted by reverses the order, any other starts with its natural order.
  def ranking_column_header(key, label)
    current = @sort == key
    direction = current ? (@direction == "asc" ? "desc" : "asc") : PlayerRanking.default_direction(@kind, key)
    path = ranking_path(@kind, rankings_filter_params.merge("sort" => key, "direction" => direction))
    arrow = current ? (@direction == "asc" ? " ▲" : " ▼") : ""

    tag.th(link_to("#{label}#{arrow}", path, class: "sort-link"), aria: { sort: (current ? (@direction == "asc" ? "ascending" : "descending") : nil) })
  end

  private

  # The season after one: its year's autumn after spring, the next year's spring after autumn.
  def next_season_key(season)
    season.term == "spring" ? [ season.year, "autumn" ] : [ season.year + 1, "spring" ]
  end

  # The period and university filters from the request, without paging or sorting.
  def rankings_filter_params
    request.query_parameters.except("page", "sort", "direction")
  end

  # The sort the page is showing when it isn't the ranking's own order. An invalid
  # sort in the URL is not carried along: the controller has already dropped it.
  def rankings_sort_params
    @custom_sort ? { "sort" => @sort, "direction" => @direction } : {}
  end
end
