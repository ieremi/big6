class Matchup
  attr_reader :team0, :team1, :games

  def initialize(team0, team1)
    @team0 = team0
    @team1 = team1
    @games = Game
      .where(team0_id: [ team0.id, team1.id ], team1_id: [ team0.id, team1.id ])
      .includes(:team0, :team1, :season)
      .order(:played_on, :game_number)
      .to_a
  end

  def wins(team, since: nil, season_id: nil)
    scoped_games(since: since, season_id: season_id).count { |g| winner(g) == team }
  end

  def draws(since: nil, season_id: nil)
    scoped_games(since: since, season_id: season_id).count { |g| winner(g).nil? }
  end

  def percentage(team, since: nil, season_id: nil)
    other = team == team0 ? team1 : team0
    decided = wins(team, since: since, season_id: season_id) + wins(other, since: since, season_id: season_id)
    decided.zero? ? nil : wins(team, since: since, season_id: season_id).to_f / decided
  end

  def average_attendance(since: nil, season_id: nil)
    values = attendance_values(since: since, season_id: season_id)
    return nil if values.empty?

    values.sum / values.size
  end

  def total_attendance(since: nil, season_id: nil)
    values = attendance_values(since: since, season_id: season_id)
    return nil if values.empty?

    values.sum
  end

  private

  def attendance_values(since: nil, season_id: nil)
    scoped_games(since: since, season_id: season_id).filter_map(&:attendance)
  end

  def scoped_games(since: nil, season_id: nil)
    scoped = games
    scoped = scoped.select { |g| g.played_on >= since } if since
    scoped = scoped.select { |g| g.season_id == season_id } if season_id
    scoped
  end

  def winner(game)
    return nil if game.team0_score == game.team1_score

    game.team0_score > game.team1_score ? game.team0 : game.team1
  end
end
