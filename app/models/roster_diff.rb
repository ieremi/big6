# What changed in a team's members from its previous game of the season (前回の
# 試合からの変更), shown on a game page above each team's roster: who came into
# the starting lineup and who left it, whose batting order or starting position
# changed, and who joined or left the bench (ベンチ入り).
#
# The members are a game's GameMember list from Scorebook, or before Scorebook
# has one, the provisional lineup from the league's box score
# (LeagueOfficialLineup), whose entries answer the same questions. A starter is
# a member with a batting order, or the starting pitcher of a game with a
# designated hitter, who has 投 and no batting order. The provisional lineup has
# only the players who played, not the bench, so the bench is compared only
# when both games have Scorebook's lists; and its positions are where the
# starters play now, so a move during the game shows as a change of position.
#
# The previous game is the team's latest game of the same season before this
# one that has members of either kind; a season's first game has none. Across
# seasons the lineups differ too much for a list of changes to say anything.
class RosterDiff
  # A starter now and then: where in the order and the field (nil when not starting).
  Move = Data.define(:player, :from_order, :to_order, :from_position, :to_position)

  attr_reader :previous_game, :new_starters, :dropped_starters, :order_changes, :position_changes, :joined, :left

  # { university_id => RosterDiff } for the two sides of the game that have
  # members now and a previous game. members_by_university is the game's
  # GameMembers by university; when it is empty, official_lineup
  # (LeagueOfficialLineup) stands in.
  def self.for_game(game, members_by_university:, official_lineup: nil)
    provisional = members_by_university.blank?
    current = provisional ? official_lineup&.by_university || {} : members_by_university

    [ game.team0, game.team1 ].each_with_object({}) do |university, diffs|
      members = current[university.id]
      next if members.blank?

      previous_game, previous_members, previous_provisional = previous_with_members(game, university)
      next unless previous_game

      diffs[university.id] = new(previous_game, previous_members, members, compare_bench: !provisional && !previous_provisional)
    end
  end

  # The team's latest earlier game of the season with members, those members,
  # and whether they are only the provisional lineup.
  def self.previous_with_members(game, university)
    candidates = Game.held.where(season_id: game.season_id)
      .where("games.team0_id = :id OR games.team1_id = :id", id: university.id)
      .where("games.played_on < ?", game.played_on)
      .includes(:team0, :team1, :season)
      .order(played_on: :desc, game_order: :desc)

    candidates.each do |candidate|
      members = candidate.game_members.where(university: university).includes(:player).to_a
      return [ candidate, members, false ] if members.any?

      lineup = LeagueOfficialLineup.new(candidate)
      provisional = lineup.present? && lineup.by_university[university.id]
      return [ candidate, provisional, true ] if provisional.present?
    end
    nil
  end

  def initialize(previous_game, previous_members, members, compare_bench:)
    @previous_game = previous_game
    @compare_bench = compare_bench

    now = starters(members)
    before = starters(previous_members)

    @new_starters = now.reject { |player_id, _| before.key?(player_id) }.values.map { |member| move(nil, member) }
    @dropped_starters = before.reject { |player_id, _| now.key?(player_id) }.values.map { |member| move(member, nil) }
    staying = now.keys & before.keys
    @order_changes = staying.filter_map { |id| move(before[id], now[id]) if before[id].batting_order != now[id].batting_order }
    @position_changes = staying.filter_map { |id| move(before[id], now[id]) if before[id].fielding_position != now[id].fielding_position }

    # The bench: everyone on the roster, but a starter who joined or left it
    # is told among the starters (from_bench? / to_bench?), not twice.
    if compare_bench
      previous_ids = previous_members.map { |member| member.player.id }.to_set
      ids = members.map { |member| member.player.id }.to_set
      @off_bench_before = (now.keys.to_set - previous_ids)
      @off_bench_now = (before.keys.to_set - ids)
      @joined = members.reject { |member| previous_ids.include?(member.player.id) || now.key?(member.player.id) }.map(&:player)
      @left = previous_members.reject { |member| ids.include?(member.player.id) || before.key?(member.player.id) }.map(&:player)
    else
      @off_bench_before = @off_bench_now = Set.new
      @joined = @left = []
    end
  end

  # Whether a new starter wasn't on the bench of the previous game at all.
  def from_outside?(player)
    @off_bench_before.include?(player.id)
  end

  # Whether a starter of the previous game isn't on the bench now at all.
  def now_outside?(player)
    @off_bench_now.include?(player.id)
  end

  # Whether the bench (everyone on the roster) was compared, not only the starters.
  def compare_bench?
    @compare_bench
  end

  def lineup_changed?
    [ new_starters, dropped_starters, order_changes, position_changes ].any?(&:present?)
  end

  def any?
    lineup_changed? || joined.any? || left.any?
  end

  private

  # { player_id => member } of the starters: a batting order, or the starting
  # pitcher without one (投, with a designated hitter). Not anyone with a
  # position: the provisional lineup gives substitutes theirs too.
  def starters(members)
    members.select { |member| member.batting_order || member.fielding_position == "投" }.index_by { |member| member.player.id }
  end

  def move(from, to)
    Move.new(player: (to || from).player, from_order: from&.batting_order, to_order: to&.batting_order,
      from_position: from&.fielding_position, to_position: to&.fielding_position)
  end
end
