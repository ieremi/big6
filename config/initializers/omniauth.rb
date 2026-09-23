# Signing in with Google (SessionsController). The client id and secret are an
# OAuth client of the site's Google Cloud project, whose redirect URIs are
# https://big6.onrender.com/auth/google_oauth2/callback and, for development,
# http://localhost:3000/auth/google_oauth2/callback.
#
# In development, OmniAuth's developer strategy is there too: a form asking for
# a name and an address, for signing in without Google (LoginPolicy still
# applies).
Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2, ENV["GOOGLE_CLIENT_ID"], ENV["GOOGLE_CLIENT_SECRET"],
    # Only to sign in: no access to anything at Google afterwards (online), so no refresh token.
    scope: "email,profile", prompt: "select_account", access_type: "online"
  provider :developer if Rails.env.development?
end

# Signing in starts with a POST carrying the page's CSRF token
# (omniauth-rails_csrf_protection), never a GET a link elsewhere could make.
OmniAuth.config.allowed_request_methods = [ :post ]
OmniAuth.config.logger = Rails.logger

# The session cookie is sent over HTTPS only in production, where the site is
# only served over HTTPS.
Rails.application.config.session_store :cookie_store, key: "_big6_session", secure: Rails.env.production?, same_site: :lax
