# A game's winning and losing pitchers when Scorebook has them the wrong way
# round: the win on a pitcher of the side that lost, and the loss on one of the
# side that won. Five games of 2025 spring to 2026 autumn, three of them on
# 2026-10-18 and 10-19 (慶大0-5明大 had its win on 慶大's 渡辺和 and its loss on
# 明大's 浦久). The pitchers are the right ones, as the league's site marks
# them (with ●, for the winner); only win and loss are swapped, and once both
# were on the same side's pitchers (2025-10-18's 明大9-2早大 had two wins).
#
# GameStatsImport stores them as Scorebook has them. The nightly check finds
# such games among our pitching lines (misplaced_game_ids) and makes a
# FixSuggestion of each (kind pitcher_decisions), and only an admin applying it
# moves each decision to the side it belongs to, keeping its pitcher
# (on_their_sides), with a notice saying so (notice). A draw, or a game with no
# score, has nothing to move.
class PitcherDecisions
  # The side that won, worked out from the score in SQL.
  WINNER_SQL = "CASE WHEN games.team0_score > games.team1_score THEN games.team0_id ELSE games.team1_id END".freeze

  # The ids of the games with a decision on the wrong side, from the stored
  # lines only (no network).
  def self.misplaced_game_ids(games = Game.all)
    games.joins(:pitching_lines)
      .where.not(team0_score: nil).where.not(team1_score: nil).where("games.team0_score <> games.team1_score")
      .where("(pitching_lines.wins > 0 AND pitching_lines.university_id <> #{WINNER_SQL}) " \
             "OR (pitching_lines.losses > 0 AND pitching_lines.university_id = #{WINNER_SQL})")
      .distinct.pluck(:id)
  end

  # Pitching lines' attributes (hashes with university_id, wins and losses) with
  # each decision on the side it belongs to: a win on the side that lost is its
  # loss, a loss on the side that won its win.
  def self.on_their_sides(game, rows)
    return rows if game.team0_score.nil? || game.team1_score.nil? || game.team0_score == game.team1_score

    winner_id = game.team0_score > game.team1_score ? game.team0_id : game.team1_id
    rows.map do |row|
      won = row[:university_id] == winner_id
      if won && row[:losses].positive?
        row.merge(wins: row[:losses], losses: 0)
      elsif !won && row[:wins].positive?
        row.merge(wins: 0, losses: row[:wins])
      else
        row
      end
    end
  end

  def initialize(game)
    @game = game
  end

  # The game's pitching lines with a decision, each as stored and as moved:
  # [[line, { wins:, losses: } moved], ...].
  def changes
    @changes ||= begin
      lines = PitchingLine.where(game: @game).includes(:player).order(:id).select { |line| line.wins.positive? || line.losses.positive? }
      rows = lines.map { |line| { university_id: line.university_id, wins: line.wins, losses: line.losses } }
      lines.zip(self.class.on_their_sides(@game, rows).map { |row| row.slice(:wins, :losses) })
    end
  end

  # Whether every decision is already on its side (Scorebook has it right, or it was moved).
  def on_their_sides?
    changes.all? { |line, moved| [ line.wins, line.losses ] == moved.values_at(:wins, :losses) }
  end

  # Moves the decisions in our pitching lines. Returns how many lines changed.
  def move!
    moving = changes.reject { |line, moved| [ line.wins, line.losses ] == moved.values_at(:wins, :losses) }
    moving.each { |line, moved| line.update!(moved) }
    @changes = nil
    moving.size
  end

  # The notice's title and body, from the decisions as stored (Scorebook's) and as moved:
  #
  #   2026年秋季 慶大 vs 明大 3回戦 の勝利投手・敗戦投手を直しました
  #
  #   2026年10月19日の慶大 vs 明大 3回戦（明大が5-0で勝利）で、勝利投手を浦久 響（明大）、敗戦投手を渡辺 和大（慶大）としました。
  #   当サイトの成績の元にしている Scorebook（東京六大学野球 公式記録室）の記録（https://big6scorebook.jp/game/2026101901）では、
  #   勝利投手が渡辺 和大（慶大）、敗戦投手が浦久 響（明大）になっていました。勝利投手は勝ったチーム（明大）の、敗戦投手は
  #   負けたチーム（慶大）の投手のはずなので、勝ちと負けを入れ替えました。
  def notice
    winner, loser, winner_score, loser_score = sides
    scorebook = changes.map { |line, _| [ line, { wins: line.wins, losses: line.losses } ] }
    record = @game.scorebook_game_id ? "の記録（#{FixSuggestion.scorebook_game_url(@game.scorebook_game_id)}）" : "の記録"

    [
      "#{@game.season.title} #{match} の勝利投手・敗戦投手を直しました",
      [
        "#{@game.played_on.strftime("%Y年%-m月%-d日")}の#{match}（#{winner.short_name}が#{winner_score}-#{loser_score}で勝利）で、#{decisions(changes, "を")}としました。",
        "当サイトの成績の元にしている Scorebook（東京六大学野球 公式記録室）#{record}では、#{decisions(scorebook, "が")}になっていました。" \
          "勝利投手は勝ったチーム（#{winner.short_name}）の、敗戦投手は負けたチーム（#{loser.short_name}）の投手のはずなので、勝ちと負けを入れ替えました。"
      ].join("\n")
    ]
  end

  private

  def match
    "#{@game.team0.short_name} vs #{@game.team1.short_name} #{@game.game_number}回戦"
  end

  def sides
    if @game.team0_score > @game.team1_score
      [ @game.team0, @game.team1, @game.team0_score, @game.team1_score ]
    else
      [ @game.team1, @game.team0, @game.team1_score, @game.team0_score ]
    end
  end

  # 「勝利投手を浦久 響（明大）、敗戦投手を渡辺 和大（慶大）」, listing two
  # pitchers where Scorebook has two wins.
  def decisions(pairs, particle)
    [ [ "勝利投手", :wins ], [ "敗戦投手", :losses ] ].filter_map do |label, field|
      pitchers = pairs.select { |_, decision| decision[field].positive? }.map { |line, _| pitcher(line) }
      "#{label}#{particle}#{pitchers.join("と")}" if pitchers.any?
    end.join("、")
  end

  def pitcher(line)
    school = line.university_id == @game.team0_id ? @game.team0 : @game.team1
    "#{line.player.name}（#{school.short_name}）"
  end
end
