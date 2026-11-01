class HomeController < ApplicationController
  NEWS_LIMIT = 3

  # The next day's games (NextGameDay) and the latest notices (Announcement)
  # under the links; all the notices are at /news.
  def index
    @next_game_day = NextGameDay.new
    @announcements = Announcement.newest_first.includes(fix_suggestion: { game: %i[season team0 team1] }).limit(NEWS_LIMIT).to_a
  end

  def og_image
    title = params[:title].presence || "Tokyo Big 6 Baseball"
    subtitle = params[:subtitle].presence

    send_data SiteOgImage.new(title: title, subtitle: subtitle).to_png, type: "image/png", disposition: "inline"
  end
end
