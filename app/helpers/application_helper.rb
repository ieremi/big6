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

  def score_span(team0_score, team1_score, played_on: nil)
    if team0_score.nil? || team1_score.nil?
      label = played_on && played_on >= Date.current ? "試合前" : "試合中"
      return tag.span(label, class: "score muted")
    end

    tag.span class: "score" do
      tag.span(team0_score, class: "score-num score-num-left") +
        tag.span("-", class: "score-sep") +
        tag.span(team1_score, class: "score-num score-num-right")
    end
  end
end
