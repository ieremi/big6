# The notices to the site's visitors (Announcement), newest first. The home page
# shows the latest few.
class NewsController < ApplicationController
  def index
    @announcements = Announcement.newest_first.includes(fix_suggestion: { game: %i[season team0 team1] })
  end
end
