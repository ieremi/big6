require "net/http"
require "uri"

# Checks our players' batting lines (imported from each game's Scorebook page by
# GameStatsImport) against Scorebook's own per-player lines (its member pages,
# ScorebookMemberStats), game by game, and sorts what differs into kinds:
#
#   missing    a game Scorebook has a line for, and we don't
#   no_stats   the same, for a game we have no one's lines for: its box score
#              isn't imported yet, or Scorebook's game page has none (the import
#              reads that page, not the member page)
#   extra      a game we have a line for, and Scorebook's member page doesn't
#   duplicate  a game Scorebook lists the player twice for (its season totals
#              count both; we keep one, so its values aren't compared)
#   value      a value both have that differs (one Difference per column)
#
# A value Scorebook didn't record is nil there and 0 here (the import stores 0);
# those aren't differences, only counted, by column, in unknown_as_zero.
#
# Games are matched by Scorebook game id, and failing that by date: Scorebook's
# member page sometimes files a line under another game of the same day.
#
# Each Difference has a key that stays the same from run to run, for the list of
# known differences script/big6/check_scorebook_stats.rb keeps.
#
#   check = ScorebookStatsCheck.new
#   differences = check.call(player)   # nil when Scorebook's page can't be read
class ScorebookStatsCheck
  RECORDS_URL = "https://big6scorebook.jp/stats/record/personal/batting".freeze

  Difference = Struct.new(:kind, :player, :scorebook_game_id, :played_on, :field, :scorebook, :ours, keyword_init: true) do
    # "value 20164001 2019041401 hits", "missing 20164001 2019042801"
    def key
      [ kind, player.scorebook_id, scorebook_game_id, field ].compact.join(" ")
    end

    def to_s
      detail = kind == "value" ? " #{field}: Scorebook #{scorebook} / ours #{ours}" : ""
      "#{key}  # #{player.name} #{played_on}#{detail}"
    end
  end

  attr_reader :unknown_as_zero

  # dates limits the games checked (both sides) to a range of dates; fetcher is
  # how a player's Scorebook lines are fetched (by Scorebook id).
  def initialize(dates: nil, fetcher: ScorebookMemberStats.method(:fetch))
    @dates = dates
    @fetcher = fetcher
    @unknown_as_zero = Hash.new(0)
  end

  # The Scorebook ids of the players on Scorebook's batting records page (its
  # career, season and single-game leaders), whose stats are the ones most
  # looked at.
  def self.record_holder_ids
    response = Net::HTTP.get_response(URI(RECORDS_URL), { "User-Agent" => ScorebookMemberStats::USER_AGENT })
    return [] unless response.is_a?(Net::HTTPSuccess)

    response.body.scan(%r{href="/member/(\d+)"}).flatten.map(&:to_i).uniq
  end

  # The player's differences, or nil when Scorebook's page can't be read.
  def call(player)
    scorebook_lines = @fetcher.call(player.scorebook_id) or return nil
    scorebook_lines = scorebook_lines.select { |line| in_dates?(line.played_on) }
    ours = our_lines(player)
    by_game_id = ours.index_by { |line| line.game.scorebook_game_id }
    by_date = ours.group_by { |line| line.game.played_on }
    matched = Set.new
    differences = []

    scorebook_lines.group_by(&:scorebook_game_id).each do |game_id, lines|
      line = lines.first
      mine = [ by_game_id[game_id], *by_date[line.played_on] ].compact.find { |candidate| !matched.include?(candidate.id) }
      matched << mine.id if mine

      if lines.size > 1
        differences << difference("duplicate", player, game_id, line.played_on)
      elsif mine.nil?
        kind = game_without_stats?(player, game_id, line.played_on) ? "no_stats" : "missing"
        differences << difference(kind, player, game_id, line.played_on)
      else
        differences.concat(value_differences(player, game_id, line, mine))
      end
    end

    ours.reject { |line| matched.include?(line.id) }.each do |line|
      differences << difference("extra", player, line.game.scorebook_game_id || "game#{line.game.id}", line.game.played_on)
    end

    differences
  end

  private

  def our_lines(player)
    lines = BattingLine.where(player_id: player.id).includes(:game)
    lines = lines.joins(:game).where(games: { played_on: @dates }) if @dates
    lines.to_a
  end

  # Whether we have the game (by its Scorebook id, or else the player's
  # university's game that day) but no one's lines for it: not imported yet, or
  # its Scorebook game page has none.
  def game_without_stats?(player, game_id, played_on)
    game = Game.find_by(scorebook_game_id: game_id)
    game = nil if game && [ game.team0_id, game.team1_id ].exclude?(player.university_id)
    game ||= Game.where(played_on: played_on).where("team0_id = :id OR team1_id = :id", id: player.university_id).first
    game.present? && !BattingLine.exists?(game_id: game.id)
  end

  def in_dates?(date)
    @dates.nil? || (date && @dates.cover?(date))
  end

  def value_differences(player, game_id, line, mine)
    line.values.filter_map do |field, value|
      ours = mine.public_send(field)
      if value.nil?
        @unknown_as_zero[field] += 1 if ours.zero?
        next
      end
      next if value == ours

      difference("value", player, game_id, line.played_on, field: field, scorebook: value, ours: ours)
    end
  end

  def difference(kind, player, game_id, played_on, **attributes)
    Difference.new(kind: kind, player: player, scorebook_game_id: game_id, played_on: played_on, **attributes)
  end
end
