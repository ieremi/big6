module Admin
  # The admin pages: for admins only (see LoginPolicy), and kept out of search
  # engines.
  class BaseController < ApplicationController
    before_action :require_admin
    before_action { response.set_header("X-Robots-Tag", "noindex, nofollow") }
  end
end
