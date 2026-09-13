module ApplicationHelper
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
  # not a path.
  def google_calendar_subscribe_url(ics_url)
    "https://calendar.google.com/calendar/render?cid=#{CGI.escape(ics_url)}"
  end

  CANCELLED_STATUSES = %w[中止 ノーゲーム].freeze

  def score_span(team0_score, team1_score, played_on: nil, status: nil)
    if team0_score.nil? || team1_score.nil?
      label = if CANCELLED_STATUSES.include?(status)
        status
      elsif played_on && played_on >= Date.current
        "試合前"
      else
        "試合中"
      end
      return tag.span(label, class: "score muted")
    end

    tag.span class: "score" do
      tag.span(team0_score, class: "score-num score-num-left") +
        tag.span("-", class: "score-sep") +
        tag.span(team1_score, class: "score-num score-num-right")
    end
  end
end
