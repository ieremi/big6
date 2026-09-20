# The filters of the player search, shared by the players page and the Web API
# so both mean the same thing by them. Unknown role or status values are
# ignored rather than rejected.
class PlayerSearch
  ROLE_GROUPS = (Player::ROLE_GROUPS.keys + [ "other" ]).freeze
  STATUSES = { "active" => Player::ACTIVE_ENROLLMENT_STATUS, "alumni" => Player::ALUMNI_ENROLLMENT_STATUS }.freeze

  # The columns of the players table that can be sorted by. Baseball positions
  # and hands sort in their usual order (投手, 捕手, 一塁手 ...), not alphabetically.
  SORT_KEYS = %w[university name enter_year role position hands high_school status].freeze
  POSITION_ORDER = %w[投手 捕手 一塁手 二塁手 三塁手 遊撃手 内野手 外野手].freeze
  HAND_ORDER = %w[右 左 両].freeze
  ROLE_ORDER = %w[player staff manager].freeze # the Player::ROLE_GROUPS, in this order, then any other role

  # Where a position, role or pair of hands comes in a sort by that column (nil
  # when blank), for tables sorted in the browser; the SQL orders below are the
  # same ones.
  def self.position_rank(position)
    position.presence && (POSITION_ORDER.index(position) || POSITION_ORDER.size)
  end

  def self.role_rank(role)
    return nil if role.blank?

    ROLE_ORDER.index { |group| Player::ROLE_GROUPS.fetch(group).include?(role) } || ROLE_ORDER.size
  end

  def self.hands_rank(player)
    pitching = player.pitching_hand.presence && (HAND_ORDER.index(player.pitching_hand) || HAND_ORDER.size)
    batting = player.batting_hand.presence && (HAND_ORDER.index(player.batting_hand) || HAND_ORDER.size)
    return nil if pitching.nil? && batting.nil?

    (pitching || HAND_ORDER.size + 1) * (HAND_ORDER.size + 2) + (batting || HAND_ORDER.size + 1)
  end

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
  #
  # sort (one of SORT_KEYS) and direction ("asc" or "desc") put another column
  # first, the display order breaking ties; blanks come last either way.
  def ordered(sort: nil, direction: nil)
    dir = direction == "desc" ? "DESC" : "ASC"
    order = SORT_KEYS.include?(sort) ? sort_expressions(sort, dir) : []
    order += [ "players.enter_year DESC NULLS LAST", "universities.position", "players.name", "players.id" ]

    players.joins(:university).preload(:university).order(Arel.sql(order.join(", ")))
  end

  private

  def sort_expressions(key, dir)
    case key
    when "university" then [ "universities.position #{dir}" ]
    when "name" then [ "COALESCE(NULLIF(players.name_kana, ''), players.name) #{dir}" ]
    when "enter_year" then [ "players.enter_year #{dir} NULLS LAST" ]
    when "role" then [ "#{role_order} #{dir} NULLS LAST", "players.role #{dir}" ]
    when "position" then [ "#{listed_order('players.position', POSITION_ORDER)} #{dir} NULLS LAST", "players.position #{dir}" ]
    when "hands"
      [ "#{listed_order('players.pitching_hand', HAND_ORDER)} #{dir} NULLS LAST", "#{listed_order('players.batting_hand', HAND_ORDER)} #{dir} NULLS LAST" ]
    when "high_school" then [ "NULLIF(players.high_school, '') #{dir} NULLS LAST" ]
    when "status" then [ "players.enrollment_status #{dir} NULLS LAST" ]
    end
  end

  # See ROLE_ORDER; NULL when blank.
  def role_order
    whens = ROLE_ORDER.each_with_index.map do |group, index|
      "WHEN players.role IN (#{Player::ROLE_GROUPS.fetch(group).map { |role| Player.connection.quote(role) }.join(', ')}) THEN #{index}"
    end
    "CASE WHEN players.role IS NULL THEN NULL #{whens.join(' ')} ELSE #{ROLE_ORDER.size} END"
  end

  # The position of the column's value in the list (values not in it come after
  # the listed ones); NULL when blank.
  def listed_order(column, list)
    whens = list.each_with_index.map { |value, index| "WHEN #{column} = #{Player.connection.quote(value)} THEN #{index}" }.join(" ")
    "CASE WHEN #{column} IS NULL THEN NULL #{whens} ELSE #{list.size} END"
  end
end
