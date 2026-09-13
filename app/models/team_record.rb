class TeamRecord
  def initialize(university)
    @university = university
    @games = Game
      .where(team0_id: university.id).or(Game.where(team1_id: university.id))
      .includes(:team0, :team1, :season)
      .order(:played_on, :game_number)
      .to_a
  end

  def wins(since: nil, season_id: nil)
    scoped_games(since: since, season_id: season_id).count { |g| winner(g) == @university }
  end

  def losses(since: nil, season_id: nil)
    scoped_games(since: since, season_id: season_id).count { |g| !winner(g).nil? && winner(g) != @university }
  end

  def draws(since: nil, season_id: nil)
    scoped_games(since: since, season_id: season_id).count { |g| winner(g).nil? }
  end

  def percentage(since: nil, season_id: nil)
    w = wins(since: since, season_id: season_id)
    l = losses(since: since, season_id: season_id)
    decided = w + l
    decided.zero? ? nil : w.to_f / decided
  end

  def average_duration_minutes(since: nil, season_id: nil)
    values = duration_values(since: since, season_id: season_id)
    return nil if values.empty?

    values.sum / values.size
  end

  def total_duration_minutes(since: nil, season_id: nil)
    values = duration_values(since: since, season_id: season_id)
    return nil if values.empty?

    values.sum
  end

  def max_duration_minutes(since: nil, season_id: nil)
    duration_values(since: since, season_id: season_id).max
  end

  def min_duration_minutes(since: nil, season_id: nil)
    duration_values(since: since, season_id: season_id).min
  end

  def duration_stddev_minutes(since: nil, season_id: nil)
    values = duration_values(since: since, season_id: season_id)
    return nil if values.size < 2

    mean = values.sum / values.size.to_f
    variance = values.sum { |v| (v - mean)**2 } / values.size
    Math.sqrt(variance).round
  end

  private

  def duration_values(since: nil, season_id: nil)
    scoped_games(since: since, season_id: season_id).filter_map { |g| GameScoreboard.new(g).duration_minutes }
  end

  def scoped_games(since: nil, season_id: nil)
    scoped = @games.select { |g| g.team0_score.present? && g.team1_score.present? }
    scoped = scoped.select { |g| g.played_on >= since } if since
    scoped = scoped.select { |g| g.season_id == season_id } if season_id
    scoped
  end

  def winner(game)
    return nil if game.team0_score.nil? || game.team1_score.nil?
    return nil if game.team0_score == game.team1_score

    game.team0_score > game.team1_score ? game.team0 : game.team1
  end
end
