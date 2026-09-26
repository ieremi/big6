# A GameDataCheck finding an admin has looked at and found fine, with why:
# it is left out of the list of findings from then on, until taken back.
class GameCheckReview < ApplicationRecord
  belongs_to :reviewed_by, class_name: "User", optional: true

  validates :key, presence: true, uniqueness: true
end
