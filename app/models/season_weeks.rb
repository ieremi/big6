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

  private

  def compute
    series_list = @games.group_by { |g| [ g.team0_id, g.team1_id ].sort }.map do |_, games|
      ordered = games.sort_by { |g| [ g.played_on, g.game_number ] }
      first_game = ordered.first
      Series.new(team0: first_game.team0, team1: first_game.team1, games: ordered)
    end

    weeks_by_start_date = series_list.group_by { |s| s.games.first.played_on }

    @weeks = weeks_by_start_date.keys.sort.each_with_index.map do |date, index|
      series = weeks_by_start_date[date]
      games = series.flat_map(&:games).sort_by { |g| [ g.played_on, g.game_number ] }
      Week.new(number: index + 1, series: series, games: games)
    end
  end
end
