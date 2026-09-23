# A member of a university's roster as listed in Scorebook's 名鑑, imported by
# PlayerSync. Covers players, managers, coaches, and so on (see role).
class Player < ApplicationRecord
  # Scorebook's enrollmentActive values: someone currently on the team, and a
  # graduate. (It also uses 3 for people who left, which nothing here shows.)
  ACTIVE_ENROLLMENT_STATUS = 1
  ALUMNI_ENROLLMENT_STATUS = 2

  # Roles held by the team's adults rather than its students, most senior first.
  STAFF_ROLES = %w[部長 副部長 監督 助監督 コーチ].freeze

  # Filter groups for the roster search; anything else (学生コーチ, アナリスト,
  # ...) falls under "other".
  ROLE_GROUPS = {
    "player" => %w[選手],
    "manager" => %w[マネージャー],
    "staff" => STAFF_ROLES
  }.freeze

  # SQL that removes every kind of whitespace from a column, including the
  # ideographic space and the no-break space some names contain.
  WHITESPACE_STRIPPED = ->(column) { "regexp_replace(#{column}, '[\\s\\u3000\\u00a0]', '', 'g')" }

  belongs_to :university
  has_many :game_members, dependent: :destroy
  has_many :batting_lines, dependent: :destroy
  has_many :pitching_lines, dependent: :destroy
  has_one :scorebook_stats_player_check, dependent: :delete
  has_many :scorebook_stats_differences, dependent: :delete_all

  scope :active, -> { where(enrollment_status: ACTIVE_ENROLLMENT_STATUS) }
  scope :students, -> { where("players.role IS NULL OR players.role NOT IN (?)", STAFF_ROLES) }

  # Members whose role is in the given ROLE_GROUPS group, or in none of them for "other".
  scope :in_role_group, lambda { |group|
    if group == "other"
      where("players.role IS NULL OR players.role NOT IN (?)", ROLE_GROUPS.values.flatten)
    else
      where(role: ROLE_GROUPS.fetch(group))
    end
  }

  # Matches the name (ignoring whitespace of any kind, including the space
  # between family and given name), its kana reading, or the high school.
  scope :matching_keyword, lambda { |keyword|
    squeezed = "%#{sanitize_sql_like(keyword.gsub(/[[:space:]]/, ''))}%"
    where(
      "#{WHITESPACE_STRIPPED.call('players.name')} ILIKE :q OR #{WHITESPACE_STRIPPED.call('players.name_kana')} ILIKE :q OR players.high_school ILIKE :q",
      q: squeezed
    )
  }

  # "右投左打" style; whichever half is known when only one is.
  def hands_label
    [ ("#{pitching_hand}投" if pitching_hand), ("#{batting_hand}打" if batting_hand) ].compact.join
  end

  # "active" for a current member, "alumni" for a graduate, nil for anyone else.
  def enrollment_state
    case enrollment_status
    when ACTIVE_ENROLLMENT_STATUS then "active"
    when ALUMNI_ENROLLMENT_STATUS then "alumni"
    end
  end

  # The Scorebook id is what identifies a player in URLs.
  def to_param
    scorebook_id.to_s
  end
end
