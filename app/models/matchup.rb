class Matchup
  attr_reader :team0, :team1, :games

  # games lets a caller that already has every team's games preloaded (e.g.
  # MatchupsController#index, building the full 6-team grid at once) pass
  # this pair's slice in, instead of each Matchup instance re-querying them
  # — significant when this runs once per pair (15 of them).
  def initialize(team0, team1, games: nil)
    @team0 = team0
    @team1 = team1
    # Not team0_id/team1_id both IN [team0.id, team1.id] — a handful of Game
    # rows have team0_id == team1_id (bad source data, a team "playing
    # itself"), which that form would incorrectly match for every pair
    # involving that one team.
    @games = games || Game
      .where(
        "(team0_id = :team0_id AND team1_id = :team1_id) OR (team0_id = :team1_id AND team1_id = :team0_id)",
        team0_id: team0.id, team1_id: team1.id
      )
      .includes(:team0, :team1, :season)
      .order(:played_on, :game_number)
      .to_a
  end

  def wins(team, since: nil, season_id: nil, year: nil)
    scoped_games(since: since, season_id: season_id, year: year).count { |g| winner(g) == team }
  end

  def draws(since: nil, season_id: nil)
    scoped_games(since: since, season_id: season_id).count { |g| winner(g).nil? }
  end

  def percentage(team, since: nil, season_id: nil)
    other = team == team0 ? team1 : team0
    decided = wins(team, since: since, season_id: season_id) + wins(other, since: since, season_id: season_id)
    decided.zero? ? nil : wins(team, since: since, season_id: season_id).to_f / decided
  end

  def longest_streak(team, since: nil, season_id: nil)
    best = nil
    length = 0
    first_game = nil

    scoped_games(since: since, season_id: season_id).each do |g|
      if winner(g) == team
        length += 1
        first_game ||= g
        best = Streak.new(team: team, length: length, first_game: first_game, last_game: g) if best.nil? || length > best.length
      else
        length = 0
        first_game = nil
      end
    end

    best
  end

  def current_streak(team, since: nil, season_id: nil)
    games = scoped_games(since: since, season_id: season_id)
    return nil if games.empty?

    length = 0
    first_game = nil
    last_game = nil

    games.reverse_each do |g|
      break unless winner(g) == team

      length += 1
      first_game = g
      last_game ||= g
    end

    return nil if length.zero?

    Streak.new(team: team, length: length, first_game: first_game, last_game: last_game)
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

  def games_for(season: nil, year: nil)
    return games if season.nil? && year.nil?

    games.select { |g| season ? g.season_id == season.id : g.season.year == year.to_i }
  end

  def period_keys_for(game, periods)
    periods.select do |_, opts|
      if opts[:since]
        game.played_on >= opts[:since]
      elsif opts[:season_id]
        game.season_id == opts[:season_id]
      else
        true
      end
    end.keys
  end

  private

  def attendance_values(since: nil, season_id: nil)
    scoped_games(since: since, season_id: season_id).filter_map(&:attendance)
  end

  def duration_values(since: nil, season_id: nil)
    scoped_games(since: since, season_id: season_id).filter_map { |g| GameScoreboard.new(g).duration_minutes }
  end

  def scoped_games(since: nil, season_id: nil, year: nil)
    scoped = games.select { |g| g.team0_score.present? && g.team1_score.present? }
    scoped = scoped.select { |g| g.played_on >= since } if since
    scoped = scoped.select { |g| g.season_id == season_id } if season_id
    scoped = scoped.select { |g| g.season.year == year.to_i } if year
    scoped
  end

  def winner(game)
    return nil if game.team0_score.nil? || game.team1_score.nil?
    return nil if game.team0_score == game.team1_score

    game.team0_score > game.team1_score ? game.team0 : game.team1
  end
end
