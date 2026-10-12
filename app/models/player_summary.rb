# A player told in a few plain sentences (選手の要約), at the top of their page and
# as its description: university and position (or a staff member's role), year
# of entry and high school, and the career totals in league games (投手: games,
# wins and losses, ERA, strikeouts; 打撃: games, average, hits, home runs, RBIs).
#
# Like GameSummary, for people and for search engines and AI search alike, and
# only what the page itself shows. The totals are of the games Scorebook has a
# box score for, as everywhere on the site; when a player's four years overlap
# seasons it has none for (most before 1977, and 2010-11 and 2014-16), the
# summary says the totals leave those out, so no one reads them as complete.
class PlayerSummary
  def initialize(player, stats)
    @player = player
    @stats = stats
  end

  def sentences
    @sentences ||= [ profile, background, pitching, batting, coverage ].compact
  end

  def to_s
    sentences.join
  end

  private

  def staff?
    Player::STAFF_ROLES.include?(@player.role)
  end

  # 「田中 優飛（タナカ ユウト）は、東京六大学野球・立教大学の投手。」
  def profile
    reading = @player.name_kana.present? ? "（#{@player.name_kana}）" : ""
    what = staff? ? @player.role : (@player.position.presence || @player.role.presence || "選手")
    "#{@player.name}#{reading}は、東京六大学野球・#{@player.university.name}の#{what}。"
  end

  # 「2024年入学、仙台育英出身。」
  def background
    parts = [ ("#{@player.enter_year}年入学" if @player.enter_year), ("#{@player.high_school}出身" if @player.high_school.present?) ].compact
    "#{parts.join('、')}。" if parts.any?
  end

  def pitching
    return nil unless @stats.pitching?

    t = @stats.pitching_total
    era = t.era ? "防御率#{format('%.2f', t.era)}" : nil
    "リーグ戦では通算#{t.games}試合に登板し、#{[ "#{t.wins}勝#{t.losses}敗", era, "#{t.strikeouts}奪三振" ].compact.join('、')}。"
  end

  def batting
    return nil unless @stats.batting?

    t = @stats.batting_total
    average = t.average ? "打率#{format('%.3f', t.average).sub(/\A0/, '')}" : nil
    lead = @stats.pitching? ? "打撃では通算#{t.games}試合で" : "リーグ戦では通算#{t.games}試合に出場し、"
    "#{lead}#{[ average, "#{t.hits}安打", "#{t.home_runs}本塁打", "#{t.rbi}打点" ].compact.join('、')}。"
  end

  # Said when the player's four years include seasons without box scores: the
  # totals leave them out, or there are none at all.
  def coverage
    return nil if @player.enter_year.nil? || staff?

    missing = PlayerRanking.seasons_without_stats("batting").map { |season| [ season.year, season.term ] }
    career = PlayerRanking.career_seasons(@player.enter_year)
    overlap = career & missing
    return nil if overlap.empty?

    if @stats.pitching? || @stats.batting?
      "成績は試合ごとの記録がある試合の集計で、記録が残っていない#{overlap.size}シーズンはふくまない。"
    elsif overlap.size == career.size
      "在籍した時期のリーグ戦は試合ごとの記録が残っておらず、成績はない。"
    end
  end
end
