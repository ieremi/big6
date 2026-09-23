# A notice to the site's visitors: the latest few on the home page, all of them
# at /news, newest first. For now each comes from applying a FixSuggestion
# (FixSuggestion#apply! makes or updates it, unapply! deletes it).
class Announcement < ApplicationRecord
  belongs_to :fix_suggestion, optional: true

  validates :title, :body, :published_at, presence: true

  scope :newest_first, -> { order(published_at: :desc, id: :desc) }

  # The game the notice is about, for a link to it (nil for one about no game).
  def game
    fix_suggestion&.game
  end

  # Whether it was changed after it was first published (more lines applied).
  def revised?
    updated_at > published_at + 1.minute
  end
end
