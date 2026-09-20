# The filters of the player search, shared by the players page and the Web API
# so both mean the same thing by them. Unknown role or status values are
# ignored rather than rejected.
class PlayerSearch
  ROLE_GROUPS = (Player::ROLE_GROUPS.keys + [ "other" ]).freeze
  STATUSES = { "active" => Player::ACTIVE_ENROLLMENT_STATUS, "alumni" => Player::ALUMNI_ENROLLMENT_STATUS }.freeze

  attr_reader :keyword, :university_ids, :start_year, :end_year, :role_group, :status

  # university_ids nil means any university; an empty array matches no one.
  # start_year / end_year bound the entry year, role_group is one of ROLE_GROUPS,
  # and status is "active" or "alumni".
  def initialize(keyword: nil, university_ids: nil, start_year: nil, end_year: nil, role_group: nil, status: nil)
    @keyword = keyword.to_s.strip.presence
    @university_ids = university_ids&.map(&:to_i)
    @start_year = start_year.presence&.to_i
    @end_year = end_year.presence&.to_i
    @role_group = role_group if ROLE_GROUPS.include?(role_group)
    @status = status if STATUSES.key?(status)
  end

  # The matching players, unordered.
  def players
    scope = Player.all
    scope = scope.matching_keyword(keyword) if keyword
    scope = scope.where(university_id: university_ids) unless university_ids.nil?
    scope = scope.where(players: { enter_year: start_year.. }) if start_year
    scope = scope.where(players: { enter_year: ..end_year }) if end_year
    scope = scope.in_role_group(role_group) if role_group
    scope = scope.where(enrollment_status: STATUSES.fetch(status)) if status
    scope
  end

  # The matching players in display order: newest entry year first (those with
  # none last), then university, then name. The id makes paging stable.
  def ordered
    players.joins(:university).preload(:university)
      .order(Arel.sql("players.enter_year DESC NULLS LAST"), "universities.position", "players.name", "players.id")
  end
end
