class SeasonWeeks
  Series = Struct.new(:team0, :team1, :games, keyword_init: true)

  Week = Struct.new(:number, :series, :games, keyword_init: true) do
    def heading
      series.map { |s| "#{s.team0.short_name} vs #{s.team1.short_name}" }.join("、")
    end
  end

  attr_reader :weeks

  def initialize(games)
    @games = games
    compute
  end

  # The weeks with only the series that one of the universities played in (nil
  # or none: all of them). The numbers stay the season's own, so week 3 is still
  # week 3 when the weeks before it are left out, and a week nobody played in
  # is left out.
  def weeks_with(university_ids)
    return weeks if university_ids.blank?

    weeks.filter_map do |week|
      series = week.series.select { |s| university_ids.include?(s.team0.id) || university_ids.include?(s.team1.id) }
      next if series.empty?

      Week.new(number: week.number, series: series, games: series.flat_map(&:games).sort_by { |g| [ g.played_on, g.game_number.to_i ] })
    end
  end

  private

  # The first game actually held, which is where a series starts: a game
  # cancelled on the first day (and replayed the next) would otherwise start the
  # series a day before the pairs that weren't rained out, and split the week,
  # depending on whether we happen to have a row for each of those cancelled
  # games. A series with none held starts on its first (cancelled) game.
  def first_held_game(ordered_games)
    ordered_games.find { |game| !game.not_held? } || ordered_games.first
  end

  def compute
    series_list = @games.group_by { |g| [ g.team0_id, g.team1_id ].sort }.map do |_, games|
      ordered = games.sort_by { |g| [ g.played_on, g.game_number.to_i ] }
      first_game = first_held_game(ordered)
      Series.new(team0: first_game.team0, team1: first_game.team1, games: ordered)
    end

    weeks_by_start_date = series_list.group_by { |s| first_held_game(s.games).played_on }

    @weeks = weeks_by_start_date.keys.sort.each_with_index.map do |date, index|
      series = weeks_by_start_date[date]
      games = series.flat_map(&:games).sort_by { |g| [ g.played_on, g.game_number.to_i ] }
      Week.new(number: index + 1, series: series, games: games)
    end
  end
end
