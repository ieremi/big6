# A member of a university's roster as listed in Scorebook's 名鑑, imported by
# PlayerSync. Covers players, managers, coaches, and so on (see role).
class Player < ApplicationRecord
  # Scorebook's enrollmentActive value for someone currently on the team.
  ACTIVE_ENROLLMENT_STATUS = 1

  belongs_to :university
  has_many :game_members, dependent: :destroy

  scope :active, -> { where(enrollment_status: ACTIVE_ENROLLMENT_STATUS) }
end
