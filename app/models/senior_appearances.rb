# 4年生の出場: for the players who entered in a year (its 4年生 in their
# fourth year), how many of each university started a league game at least
# once (スタメン: in the batting order, or the starting pitcher, who has none
# with a designated hitter, as RosterDiff counts them), were on a game's roster
# but never started (ベンチ入り), or were never on one, over their league games
# so far. From Scorebook's rosters (GameMember, from 2021) and its 名鑑 (Player,
# players still on the club only: no managers or staff, nor those who left),
# for the article at /articles/senior-appearances. The 優勝決定戦 playoffs
# count too.
class SeniorAppearances
  KINDS = %i[started bench none].freeze

  # A university's counts (university nil for all of them together).
  Row = Data.define(:university, :started, :bench, :none) do
    def total
      started + bench + none
    end

    # The kind's share of the players, 0 to 1 (0 with none).
    def share(kind)
      total.zero? ? 0.0 : public_send(kind).to_f / total
    end
  end

  attr_reader :enter_year

  def initialize(enter_year)
    @enter_year = enter_year
  end

  # Each university's row, in the league's order; only those with such players.
  def rows
    @rows ||= begin
      by_university = players.group_by(&:university_id)
      University.order(:position).filter_map do |university|
        list = by_university[university.id] or next
        row_of(university, list)
      end
    end
  end

  def total
    Row.new(university: nil, **KINDS.to_h { |kind| [ kind, rows.sum(&kind) ] })
  end

  # The last day of a league game with a roster, how far the counts go.
  def through
    GameMember.joins(:game).where(games: { counted_in_stats: true }).maximum("games.played_on")
  end

  private

  def players
    @players ||= Player.active.where(enter_year: @enter_year, role: "選手").to_a
  end

  def row_of(university, list)
    ids = list.map(&:id)
    started = (started_ids & ids).size
    on_roster = (on_roster_ids & ids).size
    Row.new(university:, started:, bench: on_roster - started, none: ids.size - on_roster)
  end

  def started_ids
    @started_ids ||= members.where("batting_order IS NOT NULL OR fielding_position = ?", "投").distinct.pluck(:player_id)
  end

  def on_roster_ids
    @on_roster_ids ||= members.distinct.pluck(:player_id)
  end

  # The league games' roster lines of these players.
  def members
    GameMember.joins(:game).where(games: { counted_in_stats: true }, player_id: players.map(&:id))
  end
end
