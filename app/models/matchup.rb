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

  def wins(team)
    games.count { |g| winner(g) == team }
  end

  def draws
    games.count { |g| winner(g).nil? }
  end

  def percentage(team)
    other = team == team0 ? team1 : team0
    decided = wins(team) + wins(other)
    decided.zero? ? 0.0 : wins(team).to_f / decided
  end

  private

  def winner(game)
    return nil if game.team0_score == game.team1_score

    game.team0_score > game.team1_score ? game.team0 : game.team1
  end
end
