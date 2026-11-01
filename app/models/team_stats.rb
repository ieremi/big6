# Each university's batting and pitching over a season (チーム成績), for the
# standings page: チーム打率 and チーム防御率 above all, which the standings'
# wins and runs don't tell. Summed in SQL from the box scores (BattingLine,
# PitchingLine) of the season's games counted in the standings (no playoff),
# so the rates are worked out from the sums (BattingLine::Totals,
# PitchingLine::Totals) the way a player's are.
#
# A box score comes in only once Scorebook publishes it, some days after the
# game, so games is how many of each university's games have one: the page
# says so when it is fewer than the games played.
class TeamStats
  Row = Data.define(:university, :games, :batting, :pitching)

  def initialize(season, universities: University.order(:position).to_a)
    @season = season
    @universities = universities
  end

  def rows
    @rows ||= begin
      batting = sums(BattingLine, BattingLine::SUMMED_COLUMNS)
      pitching = sums(PitchingLine, PitchingLine::SUMMED_COLUMNS)
      games = BattingLine.joins(:game).merge(season_games).group(:university_id).distinct.count(:game_id)

      @universities.filter_map do |university|
        next unless games[university.id].to_i.positive?

        Row.new(university:, games: games[university.id],
          batting: BattingLine::Totals.new(games: games[university.id], **batting.fetch(university.id)),
          pitching: PitchingLine::Totals.new(games: games[university.id], **pitching.fetch(university.id, PitchingLine::SUMMED_COLUMNS.index_with(0))))
      end
    end
  end

  def any?
    rows.any?
  end

  private

  def season_games
    Game.where(season_id: @season.id, counted_in_stats: true)
  end

  # { university id => { column => sum } } of the season's lines of the model.
  def sums(model, columns)
    model.joins(:game).merge(season_games).group(:university_id)
      .pluck(:university_id, *columns.map { |column| Arel.sql("SUM(#{model.table_name}.#{column})") })
      .to_h { |id, *values| [ id, columns.zip(values.map(&:to_i)).to_h ] }
  end
end
