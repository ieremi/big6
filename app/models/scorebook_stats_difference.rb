# A difference the latest check of a player found between our batting lines and
# Scorebook's member page (ScorebookStatsCheck explains the kinds). known marks
# one that has been looked at (Scorebook's own error, or ours not fixed yet),
# so the report (script/big6/check_scorebook_stats.rb) lists only the others as
# new.
class ScorebookStatsDifference < ApplicationRecord
  belongs_to :player

  # A game we have no box score for at all isn't a difference in what was
  # imported, only listed; the other kinds are.
  NOT_COUNTED_KINDS = %w[no_stats].freeze

  scope :counted, -> { where.not(kind: NOT_COUNTED_KINDS) }
  scope :unknown, -> { counted.where(known: false) }

  # Makes the player's rows the differences just found: one found again keeps
  # its row (and so when it was first found, and whether it is known), one not
  # found any more is deleted, and a new one is added.
  def self.replace_for(player, differences, now: Time.current)
    rows = differences.uniq(&:key).map do |difference|
      {
        player_id: player.id, key: difference.key, kind: difference.kind,
        scorebook_game_id: Integer(difference.scorebook_game_id, exception: false), played_on: difference.played_on,
        field: difference.field&.to_s, scorebook_value: difference.scorebook, our_value: difference.ours,
        created_at: now, updated_at: now
      }
    end

    where(player: player).where.not(key: rows.map { |row| row[:key] }).delete_all
    return if rows.empty?

    upsert_all(rows, unique_by: :key, record_timestamps: false,
      update_only: %i[kind scorebook_game_id played_on field scorebook_value our_value updated_at])
  end

  def to_s
    detail = kind == "value" ? " #{field}: Scorebook #{scorebook_value} / ours #{our_value}" : ""
    "#{key}  # #{player.name} #{played_on}#{detail}"
  end
end
