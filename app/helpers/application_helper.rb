module ApplicationHelper
  def score_span(team0_score, team1_score)
    if team0_score.nil? || team1_score.nil?
      return tag.span("試合中", class: "score muted")
    end

    tag.span class: "score" do
      tag.span(team0_score, class: "score-num score-num-left") +
        tag.span("-", class: "score-sep") +
        tag.span(team1_score, class: "score-num score-num-right")
    end
  end
end
