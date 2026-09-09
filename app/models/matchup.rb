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

  def wins(team, since: nil)
    games_since(since).count { |g| winner(g) == team }
  end

  def draws(since: nil)
    games_since(since).count { |g| winner(g).nil? }
  end

  def percentage(team, since: nil)
    other = team == team0 ? team1 : team0
    decided = wins(team, since: since) + wins(other, since: since)
    decided.zero? ? nil : wins(team, since: since).to_f / decided
  end

  def average_attendance(since: nil)
    values = games_since(since).filter_map { |g| attendance_for(g) }
    return nil if values.empty?

    values.sum / values.size
  end

  private

  def attendance_for(game)
    entry = game.season.scorebook_games&.find { |g| g["id"] == game.scorebook_game_id }
    return nil unless entry

    value = entry["attendance"].to_s.delete(",").strip
    value.to_i if value.match?(/\A\d+\z/)
  end

  def games_since(since)
    return games if since.nil?

    games.select { |g| g.played_on >= since }
  end

  def winner(game)
    return nil if game.team0_score == game.team1_score

    game.team0_score > game.team1_score ? game.team0 : game.team1
  end
end
