# One way a user signs in: a provider (google_oauth2) and the user's id there.
class Identity < ApplicationRecord
  belongs_to :user

  validates :provider, :uid, presence: true
  validates :uid, uniqueness: { scope: :provider }
end
