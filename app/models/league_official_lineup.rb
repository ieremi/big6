# Reads back the provisional roster scraped by LeagueOfficialGameScraper
# (the "lineup" key of Game#league_official_data) and resolves each entry to
# a Player, for display as a GameMember-alike stand-in until Scorebook
# publishes the game's real GameMember list (see GameMemberImport) — which
# only happens once the game (and Scorebook's own processing of it) is
# finished, well after an in-progress game already has a lineup worth
# showing.
#
# Player matching is necessarily approximate: the box score gives an
# abbreviated name (family name, plus the first character of the given name
# only when needed to tell teammates apart — "林純" for 林純司), grade, and
# high school, not a Scorebook id. Matched against currently-enrolled
# players of the right university/grade/high school whose real name starts
# with that short form; anyone not uniquely matched this way is left out
# rather than risk showing the wrong person.
class LeagueOfficialLineup
  # role is always nil — the box score has no equivalent (it only shows
  # players who batted or pitched, not each one's general roster role) —
  # kept as a field anyway so GameMember.roster_order can sort these the
  # same way it sorts real GameMember rows.
  Entry = Struct.new(:university, :player, :grade, :role, :batting_order, :fielding_position, :uniform_number, keyword_init: true)

  def initialize(game)
    @game = game
    @raw_entries = Array(game.league_official_data&.dig("lineup"))
  end

  def present?
    @raw_entries.any?
  end

  # Entry list per university id, in the order the box score listed them
  # (batters in batting order, then pitchers).
  def by_university
    @by_university ||= @raw_entries.filter_map { |raw| resolve(raw) }.group_by { |entry| entry.university.id }
  end

  private

  def resolve(raw)
    university = raw["side"] == "top" ? @game.team0 : @game.team1
    player = match_player(university, raw)
    return nil unless player

    Entry.new(university: university, player: player, grade: raw["grade"], batting_order: raw["order"], fielding_position: raw["position"])
  end

  # university + high school + name-prefix first; grade only breaks a tie,
  # not a hard filter — Player#grade isn't necessarily current as of this
  # specific game's date (it reflects whatever PlayerSync last saw), so
  # requiring an exact match loses real matches for anyone whose grade has
  # since ticked over.
  def match_player(university, raw)
    short_name = raw["name"].to_s.delete(" 　")
    return nil if short_name.blank?

    candidates = Player.active.where(university: university)
    candidates = candidates.where(high_school: raw["high_school"]) if raw["high_school"].present?
    candidates = candidates.to_a.select { |player| player.name.delete(" 　").start_with?(short_name) }

    return candidates.first if candidates.size == 1
    return nil if candidates.size < 2 || raw["grade"].nil?

    by_grade = candidates.select { |player| player.grade == raw["grade"] }
    by_grade.first if by_grade.size == 1
  end
end
