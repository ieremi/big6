module ApplicationHelper
  # The season containing the most recently played game — used for the
  # nav's "最新シーズン" link. Cached (rarely changes) so this doesn't add a
  # query to every single page render.
  def latest_season
    return @latest_season if defined?(@latest_season)

    season_id = Rails.cache.fetch("latest_season_id", expires_in: 1.hour) do
      Game.order(played_on: :desc, game_number: :desc).limit(1).pick(:season_id)
    end

    @latest_season = season_id && Season.find_by(id: season_id)
  end

  # "10:00" or "10時00分" -> "10:00 am"; "14:30" or "14時30分" -> "2:30 pm";
  # "12:06" -> "0:06 pm" (noon hour is 0, not 12, in this format).
  def clock_time_12h(text)
    return nil if text.blank?

    match = text.match(/(\d{1,2})[:時](\d{1,2})/)
    return text unless match

    hour, min = match.captures.map(&:to_i)
    period = hour < 12 ? "am" : "pm"
    format("%d:%02d %s", hour % 12, min, period)
  end

  # Opens Google Calendar's own "subscribe to this URL" confirmation dialog.
  # Undocumented but long-standing/widely-used — Google Calendar has no public
  # API for one-click subscription, this is the closest thing to it. ics_url
  # must be a full absolute URL (Google's server has to be able to fetch it),
  # not a path. Must use webcal:// (not https://) in the cid value, or Google
  # responds "Unable to subscribe... check the URL" even for a perfectly
  # valid https feed.
  def google_calendar_subscribe_url(ics_url)
    webcal_url = ics_url.sub(/\Ahttps?:\/\//, "webcal://")
    "https://calendar.google.com/calendar/render?cid=#{CGI.escape(webcal_url)}"
  end

  # A game's score. With none, its status ("試合前", "試合中", "中止", ...): status is
  # the Japanese name (Game#status_label), and without one the date decides.
  def score_span(team0_score, team1_score, played_on: nil, status: nil)
    if team0_score.nil? || team1_score.nil?
      label = status.presence || (played_on && played_on >= Date.current ? "試合前" : "試合中")
      return tag.span(label, class: "score muted")
    end


    tag.span class: "score" do
      tag.span(team0_score, class: "score-num score-num-left") +
        tag.span("-", class: "score-sep") +
        tag.span(team1_score, class: "score-num score-num-right")
    end
  end
end
