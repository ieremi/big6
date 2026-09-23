# When a player's batting lines were last checked against Scorebook's member
# page, and what the check found besides differences (ScorebookStatsDifference).
# CheckScorebookStatsJob checks a few players at a time, oldest check first, so
# every player is checked in turn over a number of nights.
class ScorebookStatsPlayerCheck < ApplicationRecord
  belongs_to :player

  # Checks the player now and records it: this row, and the player's differences
  # as ScorebookStatsDifference.replace_for keeps them. A page that can't be read
  # is recorded as such and leaves the player's differences as they were.
  # Returns the differences, or nil when the page couldn't be read.
  def self.run(player, fetcher: ScorebookMemberStats.method(:fetch), now: Time.current)
    check = ScorebookStatsCheck.new(fetcher: fetcher)
    differences = check.call(player)

    transaction do
      record = find_or_initialize_by(player: player)
      record.checked_at = now
      record.readable = !differences.nil?
      record.unknown_as_zero = check.unknown_as_zero.transform_keys(&:to_s) if differences
      record.save!
      ScorebookStatsDifference.replace_for(player, differences, now: now) if differences
    end

    differences
  end
end
