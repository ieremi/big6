# How many home runs each season had (シーズンの本塁打数), for the article on
# them: the league's total and the total per game, with the fewest, the most,
# the mean and the standard deviation, over all the seasons and by decade.
#
# Summed from the box scores (BattingLine), the games counted in the standings
# (no playoff). Only the seasons over with a box score for every one of those
# games are counted: Scorebook has none for many seasons (most of the 1950s,
# the early 2010s), and a season with some missing would count too few. A
# season whose box scores have no home run at all is left out too, and named
# (no_record): Scorebook has none for 2012 and 2013, doubles and triples
# recorded and every hrb 0 (docs/scorebook.md). The standard deviation is the
# population's (the square root of the mean squared distance from the mean),
# as the university pages' is.
class SeasonHomeRuns
  Row = Data.define(:season, :games, :home_runs) do
    def per_game
      home_runs.to_f / games
    end
  end

  # The fewest, the most (each with its rows), the mean and the standard deviation of values.
  Summary = Data.define(:count, :min, :min_rows, :max, :max_rows, :mean, :sd)

  # The seasons counted, oldest first.
  def self.rows
    all.reject { |row| row.home_runs.zero? }
  end

  # The seasons with every box score but no home run in them (no record of any), oldest first.
  def self.no_record
    all.select { |row| row.home_runs.zero? }
  end

  def self.all
    Rails.cache.fetch([ "season_home_runs/v1", Game.maximum(:updated_at)&.to_i, BattingLine.maximum(:updated_at)&.to_i, BattingLine.count ], expires_in: 1.week) do
      new.rows
    end
  end

  # Every season over with a box score for each of its games, oldest first.
  def rows
    games = Game.where(counted_in_stats: true).where.not(game_status: Game::NOT_HELD_STATUSES)
    held = games.group(:season_id).count
    open = games.where(game_status: %w[試合前 試合中]).group(:season_id).count
    boxed = BattingLine.joins(:game).merge(games).group("games.season_id").distinct.count(:game_id)
    home_runs = BattingLine.joins(:game).merge(games).group("games.season_id").sum(:home_runs)

    Season.select(:id, :year, :term).where(id: held.keys).to_a
      .select { |season| open[season.id].to_i.zero? && boxed[season.id].to_i >= held[season.id] }
      .sort_by { |season| [ season.year, season.term == "spring" ? 1 : 2 ] }
      .map { |season| Row.new(season:, games: held[season.id], home_runs: home_runs[season.id].to_i) }
  end

  # The season being played so far (今季), not counted with the others: its
  # games with a box score so far, their home runs, and how many games it has
  # in all, played or to play (the 3回戦 not yet added aren't). nil when no
  # season is on, or none of its games has a box score yet.
  Current = Data.define(:season, :games, :home_runs, :scheduled_games) do
    def per_game
      home_runs.to_f / games
    end

    # The home runs at this rate over all its games.
    def projected
      (per_game * scheduled_games).round
    end
  end

  def self.current
    games = Game.where(counted_in_stats: true).where.not(game_status: Game::NOT_HELD_STATUSES)
    season_id = games.where(game_status: %w[試合前 試合中]).where(played_on: ActiveSupport::TimeZone["Asia/Tokyo"].today..).pick(:season_id)
    return nil unless season_id

    season_games = games.where(season_id:)
    boxed = BattingLine.joins(:game).merge(season_games).distinct.count(:game_id)
    return nil if boxed.zero?

    Current.new(season: Season.select(:id, :year, :term).find(season_id), games: boxed,
      home_runs: BattingLine.joins(:game).merge(season_games).sum(:home_runs), scheduled_games: season_games.count)
  end

  # How many seasons with games aren't counted for want of a box score for some
  # of their games (the season being played among them).
  def self.without_box_scores
    Game.where(counted_in_stats: true).where.not(game_status: Game::NOT_HELD_STATUSES).distinct.count(:season_id) - all.size
  end

  # { decade => how many seasons of it were played and are over }, to set the
  # seasons counted against: 1960 for the 1960s.
  def self.seasons_by_decade
    games = Game.where(counted_in_stats: true).where.not(game_status: Game::NOT_HELD_STATUSES)
    open = games.where(game_status: %w[試合前 試合中]).distinct.pluck(:season_id)
    Season.where(id: games.select(:season_id)).where.not(id: open).pluck(:year).map { |year| year / 10 * 10 }.tally.sort.to_h
  end

  def self.summary(rows, &value)
    return nil if rows.empty?

    values = rows.map(&value)
    mean = values.sum.to_f / values.size
    min, max = values.minmax
    Summary.new(count: rows.size, min:, min_rows: rows.select { |row| value.(row) == min }, max:,
      max_rows: rows.select { |row| value.(row) == max }, mean:, sd: Math.sqrt(values.sum { |v| (v - mean)**2 } / values.size))
  end
end
