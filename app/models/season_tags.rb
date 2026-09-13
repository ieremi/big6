class SeasonTags
  Tag = Struct.new(:label, keyword_init: true)

  TOKYO_POINT = "東大が勝ち点"
  CHAMPION_SWEPT = "勝ち点5で優勝"
  PERFECT_CHAMPION = "全勝で優勝"
  CHAMPION_NARROW = "勝ち点3で優勝"
  BIG_ATTENDANCE = "観衆50万人超え"
  MANY_GAMES = "40試合超え"
  NO_ROUND_3 = "3回戦がなかった"
  HAD_PLAYOFF = "優勝決定戦があった"
  WASEDA_KEIO_B_CLASS = "早慶ともにBクラス"
  RIKKYO_A_CLASS = "立大がAクラス"

  LABELS = [
    TOKYO_POINT,
    CHAMPION_SWEPT,
    PERFECT_CHAMPION,
    CHAMPION_NARROW,
    BIG_ATTENDANCE,
    MANY_GAMES,
    NO_ROUND_3,
    HAD_PLAYOFF,
    WASEDA_KEIO_B_CLASS,
    RIKKYO_A_CLASS
  ].freeze

  def initialize(season)
    @season = season
  end

  def tags
    return [] if @season.games.empty?
    return [] unless @season.finished?

    [
      tokyo_won_a_point,
      champion_swept,
      perfect_champion,
      champion_narrow,
      big_attendance,
      many_games,
      no_round_3,
      had_playoff,
      waseda_keio_both_b_class,
      rikkyo_a_class
    ].compact
  end

  private

  def standings
    @standings ||= Standings.new(@season)
  end

  def tokyo_won_a_point
    row = row_for("tokyo")
    Tag.new(label: TOKYO_POINT) if row && row.points.positive?
  end

  def champion_swept
    champion = standings.rows.first
    Tag.new(label: CHAMPION_SWEPT) if champion && champion.points == 5
  end

  def perfect_champion
    champion = standings.rows.first
    Tag.new(label: PERFECT_CHAMPION) if champion && champion.games.positive? && champion.losses.zero?
  end

  def champion_narrow
    champion = standings.rows.first
    Tag.new(label: CHAMPION_NARROW) if champion && champion.points == 3
  end

  def big_attendance
    total = @season.games.where.not(attendance: nil).sum(:attendance)
    Tag.new(label: BIG_ATTENDANCE) if total > 500_000
  end

  def many_games
    Tag.new(label: MANY_GAMES) if @season.games.size >= 40
  end

  def no_round_3
    Tag.new(label: NO_ROUND_3) if @season.games.where(game_number: 3).none?
  end

  def had_playoff
    return nil if @season.scorebook_games.blank?

    has_playoff = @season.scorebook_games.any? { |g| g["gameSuffix"] == "優勝決定戦" || g["round"] == "優勝決定戦" }
    Tag.new(label: HAD_PLAYOFF) if has_playoff
  end

  def waseda_keio_both_b_class
    Tag.new(label: WASEDA_KEIO_B_CLASS) if b_class?("waseda") && b_class?("keio")
  end

  def rikkyo_a_class
    Tag.new(label: RIKKYO_A_CLASS) if a_class?("rikkio")
  end

  def row_for(slug)
    university = University.find_by(slug: slug)
    university && standings.row_for(university)
  end

  def rank_for(slug)
    university = University.find_by(slug: slug)
    return nil unless university

    standings.rows.index { |r| r.university == university }
  end

  def a_class?(slug)
    rank = rank_for(slug)
    rank && rank < 3
  end

  def b_class?(slug)
    rank = rank_for(slug)
    rank && rank >= 3
  end
end
