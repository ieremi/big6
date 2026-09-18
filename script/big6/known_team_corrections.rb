# Scorebook's own source data has topTeamId == bottomTeamId for these 6
# games (a team "playing itself"), confirmed by inspecting the raw
# scorebook_games entries directly — not a bug in our import. team0 (from
# topTeamId) is left as Scorebook recorded it; only the opponent
# (bottomTeamId -> team1) is corrected here, to the team inferred from the
# surrounding schedule (see each `note`). All 6 predate the official
# league site's usable range (LEAGUE_OFFICIAL_MIN_YEAR = 2005), so none of
# this could be cross-checked against a second source — treat these as
# well-reasoned but unverified.
#
# Shared between game.rb (applies this at import time, so a re-sync doesn't
# recreate the team0_id == team1_id row) and fix_team_corrections.rb (which
# applies it to already-imported rows).
KNOWN_TEAM_CORRECTIONS = {
  1966042502 => {
    team1_slug: "tokyo",
    note: "Scorebook元データはteam0=team1(立大)の自己対戦。同じ週(第2週)の1回戦が" \
      "「東大vs立大」で、他の組み合わせ(法大vs明大)は1回戦・2回戦とも同一カードだったため、" \
      "2回戦の相手も東大と推定。"
  },
  1996102601 => {
    team1_slug: "rikkio",
    note: "Scorebook元データはteam0=team1(法大)の自己対戦。同じ週(第7週)の2回戦が" \
      "「法大vs立大」だったため、1回戦の相手も立大と推定。"
  },
  1997051801 => {
    team1_slug: "keio",
    note: "Scorebook元データはteam0=team1(法大)の自己対戦。同じ週(第6週)の1回戦が" \
      "「慶大3-法大1」で、この週に3回戦が存在しない(=2戦目で決着)ことから、" \
      "2回戦の相手も慶大と推定(慶大が2連勝で決着)。"
  },
  1997101401 => {
    team1_slug: "rikkio",
    note: "Scorebook元データはteam0=team1(明大)の自己対戦。同じ週(第5週)に" \
      "立大vs明大が1回戦引分(3-3)、2回戦立大勝、3回戦明大勝と1勝1敗1分になっており、" \
      "決着のための4回戦と推定。相手は立大。"
  },
  1981053001 => {
    team1_slug: "keio",
    note: "Scorebook元データはteam0=team1(早大)の自己対戦。第8週(最終週)にこの試合と" \
      "1981053101のみが記録されており、東京六大学野球の伝統で最終週は早慶戦のみ単独開催" \
      "されることから、相手は慶大と推定。"
  },
  1981053101 => {
    team1_slug: "waseda",
    note: "Scorebook元データはteam0=team1(慶大)の自己対戦。1981053001と同じ理由" \
      "(最終週の早慶戦)により、相手は早大と推定。"
  }
}.freeze unless defined?(KNOWN_TEAM_CORRECTIONS)
