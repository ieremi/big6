# Someone who can sign in (see LoginPolicy for who may). admin opens the admin
# pages; it follows ADMIN_EMAILS, and is set again at each sign-in.
class User < ApplicationRecord
  has_many :identities, dependent: :destroy

  validates :email, presence: true, uniqueness: { case_sensitive: false }

  normalizes :email, with: ->(email) { LoginPolicy.normalize(email) }

  # The user an OmniAuth sign-in (request.env["omniauth.auth"]) is for, created
  # along with the identity the first time, and brought up to date (name,
  # admin, when they last signed in) each time. The caller checks LoginPolicy
  # first.
  def self.sign_in_from(auth, now: Time.current)
    email = LoginPolicy.normalize(auth.info.email)

    transaction do
      identity = Identity.find_or_initialize_by(provider: auth.provider, uid: auth.uid.to_s)
      user = identity.user || find_or_initialize_by(email: email)
      user.update!(name: auth.info.name.presence || user.name, admin: LoginPolicy.admin?(email), last_signed_in_at: now)
      identity.update!(user: user, email: email)
      user
    end
  end
end
