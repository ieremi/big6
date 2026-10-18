module Admin
  # The admin pages' front page.
  class DashboardController < BaseController
    def show
      @progress = CheckProgress.new
    end
  end
end
