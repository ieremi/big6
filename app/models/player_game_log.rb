# A player's games for the player page's game list: every game they have a
# batting line or a roster entry for, most recent first, each with both (either
# may be nil: a game on the bench without batting, or one before 2021, when
# Scorebook starts listing rosters).
class PlayerGameLog
  Entry = Struct.new(:game, :member, :batting, keyword_init: true)

  # batting_lines and members are the player's, with their games (and the
  # games' seasons and teams) loaded.
  def initialize(batting_lines:, members:)
    @batting_lines = batting_lines
    @members = members
  end

  def entries
    @entries ||= begin
      by_game = {}
      @batting_lines.each { |line| (by_game[line.game_id] ||= Entry.new(game: line.game)).batting = line }
      @members.each { |member| (by_game[member.game_id] ||= Entry.new(game: member.game)).member = member }
      by_game.values.sort_by { |entry| [ entry.game.played_on, entry.game.game_number.to_i ] }.reverse
    end
  end

  def size
    entries.size
  end

  def any?
    entries.any?
  end
end
