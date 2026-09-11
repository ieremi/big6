class Standings
  Row = Struct.new(:university, :wins, :losses, :draws, :points, :games, :attendance_total, :attendance_count, keyword_init: true) do
    def percentage
      decided = wins + losses
      decided.zero? ? 0.0 : wins.to_f / decided
    end

    def average_attendance
      attendance_count.zero? ? nil : attendance_total / attendance_count
    end
  end

  attr_reader :season, :universities, :rows

  def initialize(season)
    @season = season
    @universities = University.order(:position).to_a
    compute
  end

  def row_for(university)
    @rows_by_id[university.id]
  end

  def results_between(a, b)
    @results[[a.id, b.id]] || []
  end

  def attendances_between(a, b)
    @attendances[[a.id, b.id]] || []
  end

  private

  def compute
    games = season.games.includes(:team0, :team1).order(:played_on, :game_number)

    tallies = universities.each_with_object({}) { |u, h| h[u.id] = { wins: 0, losses: 0, draws: 0, attendance_total: 0, attendance_count: 0 } }
    pair_games = Hash.new { |h, k| h[k] = [] }

    games.each do |g|
      case winner_id(g)
      when g.team0_id
        tallies[g.team0_id][:wins] += 1
        tallies[g.team1_id][:losses] += 1
      when g.team1_id
        tallies[g.team1_id][:wins] += 1
        tallies[g.team0_id][:losses] += 1
      else
        tallies[g.team0_id][:draws] += 1
        tallies[g.team1_id][:draws] += 1
      end

      if g.attendance
        tallies[g.team0_id][:attendance_total] += g.attendance
        tallies[g.team0_id][:attendance_count] += 1
        tallies[g.team1_id][:attendance_total] += g.attendance
        tallies[g.team1_id][:attendance_count] += 1
      end

      pair_games[[g.team0_id, g.team1_id].sort] << g
    end

    points = Hash.new(0)
    @results = {}
    @attendances = {}

    pair_games.each do |(a_id, b_id), pair|
      wins_a = pair.count { |g| winner_id(g) == a_id }
      wins_b = pair.count { |g| winner_id(g) == b_id }
      points[a_id] += 1 if wins_a >= 2
      points[b_id] += 1 if wins_b >= 2

      @results[[a_id, b_id]] = pair.map { |g| symbol_for(g, a_id) }
      @results[[b_id, a_id]] = pair.map { |g| symbol_for(g, b_id) }

      attendances = pair.map(&:attendance)
      @attendances[[a_id, b_id]] = attendances
      @attendances[[b_id, a_id]] = attendances
    end

    @rows_by_id = universities.each_with_object({}) do |u, h|
      t = tallies[u.id]
      h[u.id] = Row.new(
        university: u,
        wins: t[:wins],
        losses: t[:losses],
        draws: t[:draws],
        points: points[u.id],
        games: t[:wins] + t[:losses] + t[:draws],
        attendance_total: t[:attendance_total],
        attendance_count: t[:attendance_count]
      )
    end

    @rows = @rows_by_id.values.sort_by { |r| [-r.points, -r.percentage] }
  end

  def winner_id(game)
    return nil if game.team0_score == game.team1_score

    game.team0_score > game.team1_score ? game.team0_id : game.team1_id
  end

  def symbol_for(game, team_id)
    winner = winner_id(game)
    return "△" if winner.nil?

    winner == team_id ? "○" : "●"
  end
end
