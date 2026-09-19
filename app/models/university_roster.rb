# A university's current roster for display: its staff, as listed on its most
# recent game roster (Scorebook doesn't flag current staff as active), and the
# students Scorebook marks as currently enrolled, grouped by entry year.
class UniversityRoster
  def initialize(university)
    @university = university
  end

  # GameMember entries (with players loaded) for the university's staff on its
  # latest game that has a roster, most senior first. Empty when no game has one.
  def staff
    @staff ||= begin
      game_id = GameMember.joins(:game).where(university_id: @university.id)
        .order("games.played_on DESC, games.game_number DESC").pick(:game_id)
      members = game_id ? GameMember.where(game_id: game_id, university_id: @university.id, role: Player::STAFF_ROLES).includes(:player).to_a : []
      GameMember.roster_order(members)
    end
  end

  # { entry_year => [Player, ...] }, newest entry year first.
  def students_by_entry_year
    @students_by_entry_year ||= @university.players.active.students.order(enter_year: :desc, name: :asc).group_by(&:enter_year)
  end

  def student_count
    students_by_entry_year.values.sum(&:size)
  end
end
