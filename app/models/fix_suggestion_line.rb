# One Scorebook line a FixSuggestion is about: a player's batting in one game,
# as Scorebook's member page has it. values is keyed as
# ScorebookMemberStats::FIELDS (strings), nil where Scorebook didn't record it.
class FixSuggestionLine < ApplicationRecord
  belongs_to :fix_suggestion
  belongs_to :player

  def value(field)
    values[field.to_s]
  end
end
