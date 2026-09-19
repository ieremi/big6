# A player's batting and pitching stats for display: season rows and a career
# total summed from their per-game lines, plus the per-game lines themselves.
# Games Scorebook leaves out of official stats (the 優勝決定戦 playoffs, flagged
# counted_in_stats: false) are shown as game lines but not added into totals.
class PlayerStats
  SeasonRow = Struct.new(:season, :totals)

  def initialize(player)
    @player = player
  end

  def batting?
    batting_lines.any?
  end

  def pitching?
    pitching_lines.any?
  end

  # Per-game lines, most recent first.
  def batting_lines
    @batting_lines ||= sorted_by_game(@player.batting_lines)
  end

  def pitching_lines
    @pitching_lines ||= sorted_by_game(@player.pitching_lines)
  end

  # Season rows, oldest first; each with a BattingLine::Totals.
  def batting_seasons
    season_rows(batting_lines, BattingLine)
  end

  def pitching_seasons
    season_rows(pitching_lines, PitchingLine)
  end

  def batting_total
    BattingLine.totals(counted(batting_lines))
  end

  def pitching_total
    PitchingLine.totals(counted(pitching_lines))
  end

  private

  def sorted_by_game(association)
    association.includes(game: [ :season, :team0, :team1 ]).to_a.sort_by { |line| [ line.game.played_on, line.game.game_number ] }.reverse
  end

  def counted(lines)
    lines.select { |line| line.game.counted_in_stats }
  end

  def season_rows(lines, line_class)
    counted(lines).group_by { |line| line.game.season }
      .sort_by { |season, _| [ season.year, season.term == "spring" ? 0 : 1 ] }
      .map { |season, season_lines| SeasonRow.new(season, line_class.totals(season_lines)) }
  end
end
