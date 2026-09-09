module ApplicationHelper
  def score_span(team0_score, team1_score)
    tag.span class: "score" do
      tag.span(team0_score, class: "score-num score-num-left") +
        tag.span("-", class: "score-sep") +
        tag.span(team1_score, class: "score-num score-num-right")
    end
  end
end
