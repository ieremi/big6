# A fix to our data, suggested from Scorebook lines the nightly check
# (ScorebookStatsPlayerCheck) finds filed under the wrong game, for an admin to
# approve or discard on the admin pages. Approving records the decision; an
# approved suggestion's lines are then added to our batting lines only when an
# admin applies it (apply!), and can be taken out again (unapply!).
#
# Two kinds, from a line whose team (a university) isn't one of its game's two
# sides:
#
#   misfiled_lines   the game's sides are two other universities: the line is a
#                    game of the same day's, filed under the wrong game id. Our
#                    game that day for the line's university is where it belongs.
#                    One suggestion per game id and university, gathering the
#                    lines of the whole team as its players are checked.
#   same_team_game   the game's two sides are the same university: Scorebook's
#                    game itself is wrong (its opponent). Only listed, for review.
#
# confidence is "likely" when the guess is the only game it can be, and
# "needs_review" otherwise (several games that day, none, or the second kind).
# The evidence for a guess is worked out when shown (hits_check,
# roster_check, ...), so it grows with the lines gathered.
class FixSuggestion < ApplicationRecord
  KINDS = %w[misfiled_lines same_team_game].freeze
  SCOREBOOK_GAME_URL = "https://big6scorebook.jp/game/%d".freeze
  # not_needed: undecided, but nothing to fix here (every line is already in our
  # batting lines, with the same values: only Scorebook's member page files it
  # under the wrong game). Set and unset by classify!, not by an admin.
  STATUSES = %w[pending not_needed approved discarded].freeze
  UNDECIDED = %w[pending not_needed].freeze
  DECISIONS = %w[pending approved discarded].freeze # what an admin can set

  # Where a line stands against our batting lines in the guessed game:
  # :no_game (no game guessed), :to_apply (not there yet), :stray (not there,
  # and not to be: the player has a twin line, twin_of), :applied (added by
  # applying this suggestion), :imported_match or :imported_differs (imported
  # from Scorebook's game page, with the same values or not). differences lists
  # [field, Scorebook's value, ours] for :imported_differs.
  LineState = Struct.new(:line, :state, :ours, :differences, keyword_init: true)

  belongs_to :university, optional: true
  belongs_to :game, optional: true
  belongs_to :decided_by, class_name: "User", optional: true
  belongs_to :applied_by, class_name: "User", optional: true
  has_many :lines, -> { order(:id) }, class_name: "FixSuggestionLine", dependent: :delete_all
  has_many :applied_batting_lines, class_name: "BattingLine", dependent: :restrict_with_exception
  has_one :announcement, dependent: :destroy

  # A change the suggestion's state doesn't allow (applying one not approved,
  # changing the decision on one applied, ...), with a message for the admin.
  class NotAllowed < StandardError; end

  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }

  scope :pending, -> { where(status: "pending") }

  # Records what the lines of a player's Scorebook member page
  # (ScorebookMemberStats) suggest: each line filed under the wrong game joins
  # the suggestion for it, which is made the first time. A line already
  # recorded is left as it is, and a suggestion already decided (discarded
  # included) is never made again.
  def self.record_from(player, lines)
    touched = lines.filter_map do |line|
      teams = Array(line.game_team_ids)
      next if line.team_id.nil? || line.line_id.nil? || teams.compact.size < 2

      suggestion = if teams.uniq.size == 1
        same_team_game_for(line, player)
      elsif teams.exclude?(line.team_id)
        misfiled_lines_for(line)
      end
      next unless suggestion

      record = suggestion.lines.find_or_initialize_by(scorebook_line_id: line.line_id)
      if record.new_record?
        record.player = player
        record.position = line.position
        record.values = line.values.transform_keys(&:to_s)
      end
      # Set on lines recorded before too, as their players are checked again.
      record.twin_scorebook_game_id = twin_of(line, lines)&.scorebook_game_id
      record.save! if record.changed?
      suggestion
    end

    touched.uniq.each(&:classify!)
  end

  # The player's line of the same day filed under a game of the player's own
  # university, when a line filed under the wrong game has one: then the
  # wrong game's line isn't the player's missing line of that day, but some
  # other box score that has strayed in.
  def self.twin_of(line, lines)
    lines.find do |other|
      teams = Array(other.game_team_ids)
      other.line_id != line.line_id && other.played_on == line.played_on && teams.uniq.size > 1 && teams.include?(line.team_id)
    end
  end

  # Whether every line gathered has a twin (twin_of): the lines are a box score
  # of another game that has strayed in under the wrong game, not lines our
  # guessed game is missing, so they aren't to be added to it.
  def stray?
    lines.any? && lines.all?(&:twin_scorebook_game_id)
  end

  # Moves an undecided suggestion between pending and not_needed as its lines
  # stand now (not_needed?). A decided one (approved, discarded) is left alone.
  def classify!
    return unless UNDECIDED.include?(status)

    wanted = not_needed? ? "not_needed" : "pending"
    update!(status: wanted) unless status == wanted
  end

  # classify! for every undecided suggestion: our batting lines change as games
  # are imported, so a suggestion's standing can change without new lines.
  def self.classify_undecided!
    where(status: UNDECIDED).includes(:lines, game: %i[team0 team1]).find_each(&:classify!)
  end

  # Whether there is nothing to fix: a misfiled_lines suggestion whose every
  # line is already among our batting lines of the guessed game, imported from
  # Scorebook with the same values.
  def not_needed?
    kind == "misfiled_lines" && game.present? && lines.any? && line_states.all? { |state| state.state == :imported_match }
  end

  # Each line's LineState: whether the guessed game already has the player's
  # batting line, from where, and whether its values agree (values Scorebook
  # didn't record aren't compared, as they are 0 here).
  def line_states
    return lines.map { |line| LineState.new(line: line, state: :no_game, differences: []) } unless game

    ours = BattingLine.where(game: game, player_id: lines.map(&:player_id)).index_by(&:player_id)
    lines.map do |line|
      mine = ours[line.player_id]
      if mine.nil?
        LineState.new(line: line, state: line.twin_scorebook_game_id ? :stray : :to_apply, differences: [])
      elsif mine.fix_suggestion_id == id
        LineState.new(line: line, state: :applied, ours: mine, differences: [])
      else
        differences = ScorebookMemberStats::FIELDS.keys.filter_map do |field|
          value = line.value(field)
          [ field, value, mine.public_send(field) ] unless value.nil? || value == mine.public_send(field)
        end
        LineState.new(line: line, state: differences.empty? ? :imported_match : :imported_differs, ours: mine, differences: differences)
      end
    end
  end

  def self.misfiled_lines_for(line)
    university = university_for(line.team_id) or return nil

    find_or_create_by!(key: "misfiled_lines #{line.scorebook_game_id} #{line.team_id}") do |suggestion|
      candidates = Game.where(played_on: line.played_on).where("team0_id = :id OR team1_id = :id", id: university.id).order(:id).pluck(:id)
      suggestion.kind = "misfiled_lines"
      suggestion.university = university
      suggestion.scorebook_game_id = line.scorebook_game_id
      suggestion.played_on = line.played_on
      suggestion.candidate_game_ids = candidates
      suggestion.game_id = candidates.first if candidates.size == 1
      suggestion.confidence = candidates.size == 1 ? "likely" : "needs_review"
    end
  end

  def self.same_team_game_for(line, player)
    find_or_create_by!(key: "same_team_game #{line.scorebook_game_id}") do |suggestion|
      suggestion.kind = "same_team_game"
      suggestion.university = university_for(line.team_id) || player.university
      suggestion.scorebook_game_id = line.scorebook_game_id
      suggestion.played_on = line.played_on
      suggestion.game = Game.find_by(scorebook_game_id: line.scorebook_game_id)
      suggestion.confidence = "needs_review"
    end
  end

  def self.university_for(scorebook_team_id)
    slug = ScorebookSync::SCOREBOOK_TEAM_SLUGS[scorebook_team_id] or return nil
    University.find_by(slug: slug)
  end

  # The game Scorebook files the lines under, as we have it (nil if we don't).
  def filed_under_game
    Game.find_by(scorebook_game_id: scorebook_game_id)
  end

  def candidate_games
    Game.where(id: candidate_game_ids).includes(:team0, :team1).order(:id)
  end

  # Records an admin's decision: "approved", "discarded", or "pending" to take
  # one back. The note, when given, replaces the one kept.
  #
  # not_needed isn't a decision (classify! sets it); taking one back to pending
  # classifies it again, so one with nothing to fix goes back to not_needed.
  def decide!(status, user:, note: nil)
    raise ArgumentError, "unknown decision: #{status.inspect}" unless DECISIONS.include?(status)
    raise NotAllowed, "成績に反映済みです。決定を変えるには、先に反映を取り消してください。" if status != "approved" && applied?

    decided = status != "pending"
    update!(status: status, decided_by: (user if decided), decided_at: (Time.current if decided), note: note.nil? ? self.note : note.presence)
    classify!
  end

  # Whether any of our batting lines came from applying this suggestion.
  def applied?
    applied_batting_lines.exists?
  end

  # Whether it can be applied: approved, a misfiled_lines one with its game
  # guessed (the only kind that says where the lines go).
  def applicable?
    status == "approved" && kind == "misfiled_lines" && game.present? && university.present?
  end

  # The lines applying would add: those whose player has no batting line in the
  # guessed game yet (one imported from Scorebook, or added before, stays),
  # and that aren't strays (a line with a twin: another game's box score).
  def lines_to_apply
    return [] unless game

    have = BattingLine.where(game: game).pluck(:player_id)
    lines.reject { |line| have.include?(line.player_id) || line.twin_scorebook_game_id }
  end

  # Adds the lines to our batting lines, as lines of the guessed game for the
  # university, marked as this suggestion's; lines_to_apply says which. Values
  # Scorebook didn't record are 0, as the import stores them. Can be run again
  # for lines gathered since. Returns how many were added.
  #
  # Also publishes the notice about it (Announcement), or updates it when
  # applied again: with the title and body given, or else the default ones
  # (default_announcement). An existing notice keeps when it was published.
  def apply!(user:, title: nil, body: nil, now: Time.current)
    raise NotAllowed, "承認済みで、試合が1つに絞れている提案だけ反映できます。" unless applicable?

    transaction do
      rows = lines_to_apply.map { |line| batting_attributes(line, now) }
      BattingLine.insert_all!(rows) if rows.any?
      update!(applied_at: now, applied_by: user)

      default_title, default_body = default_announcement
      notice = Announcement.find_or_initialize_by(fix_suggestion_id: id) { |created| created.published_at = now }
      notice.update!(title: title.presence || default_title, body: body.presence || default_body)
      association(:announcement).reset
      rows.size
    end
  end

  # Takes the lines applying added out of our batting lines again, and the
  # notice about them off the site. Returns how many lines were removed.
  def unapply!
    transaction do
      # Not applied_batting_lines.delete_all: through the association that would
      # only clear their fix_suggestion_id, leaving them as imported lines.
      removed = BattingLine.where(fix_suggestion_id: id).delete_all
      Announcement.where(fix_suggestion_id: id).destroy_all
      association(:announcement).reset
      update!(applied_at: nil, applied_by: nil)
      removed
    end
  end

  # The notice's title and body as they would be with the lines applied so far
  # and those still to apply, one line of the body for each player's line:
  #
  #   2025年秋季 早大 vs 法大 2回戦 の法大の打撃成績を補いました
  #
  #   2025年10月5日の早大 vs 法大 2回戦で、法大の打撃成績が当サイトに入っていなかったため、次の2人分を補いました。
  #   ・藤森 康淳：5打席5打数4安打（二塁打1、打点1、得点1、盗塁1）
  #   ・松下 歩叶：5打席4打数1安打（三振1、四死球1）
  #   当サイトの成績の元にしている Scorebook ... で、この試合（https://big6scorebook.jp/game/2025100502）
  #   の法大の打撃成績が同じ日の別の試合（https://big6scorebook.jp/game/2025100501）に登録されているためです。
  #
  # The Scorebook pages of both games are given as URLs, which the notice's
  # page shows as links (NewsHelper#linked_text).
  def default_announcement
    applied_ids = applied_batting_lines.pluck(:player_id)
    added = (lines.includes(:player).select { |line| applied_ids.include?(line.player_id) } + lines_to_apply).sort_by(&:id)
    match = "#{game.team0.short_name} vs #{game.team1.short_name} #{game.game_number}回戦"
    date = game.played_on.strftime("%Y年%-m月%-d日")
    school = university.short_name
    this_game = game.scorebook_game_id ? "この試合（#{self.class.scorebook_game_url(game.scorebook_game_id)}）" : "この試合"
    other_game = scorebook_game_id ? "同じ日の別の試合（#{self.class.scorebook_game_url(scorebook_game_id)}）" : "同じ日の別の試合"

    [
      "#{game.season.title} #{match} の#{school}の打撃成績を補いました",
      [
        "#{date}の#{match}で、#{school}の打撃成績が当サイトに入っていなかったため、次の#{added.size}人分を補いました。",
        *added.map { |line| "・#{line.player.name}：#{self.class.batting_summary(line)}" },
        "当サイトの成績の元にしている Scorebook（東京六大学野球 公式記録室）で、#{this_game}の#{school}の打撃成績が#{other_game}に登録されているためです。"
      ].join("\n")
    ]
  end

  # The counts a notice lists after a line's plate appearances, at-bats and
  # hits, when not 0 (or not recorded).
  SUMMARY_COUNTS = {
    doubles: "二塁打", triples: "三塁打", home_runs: "本塁打", rbi: "打点", runs: "得点", strikeouts: "三振",
    walks: "四死球", sacrifices: "犠打・犠飛", stolen_bases: "盗塁", gidp: "併殺打", fielding_errors: "失策"
  }.freeze

  # A FixSuggestionLine in words: "5打席5打数4安打（二塁打1、打点1、得点1、盗塁1）".
  def self.batting_summary(line)
    head = "#{line.value(:pa).to_i}打席#{line.value(:ab).to_i}打数#{line.value(:hits).to_i}安打"
    rest = SUMMARY_COUNTS.filter_map { |field, label| "#{label}#{line.value(field)}" if line.value(field).to_i.positive? }
    rest.empty? ? head : "#{head}（#{rest.join("、")}）"
  end

  # A game's page on Scorebook.
  def self.scorebook_game_url(scorebook_game_id)
    format(SCOREBOOK_GAME_URL, scorebook_game_id)
  end

  # The hits of the lines gathered so far against the team's hits on the
  # guessed game's scoreboard: { lines:, scoreboard: }, scoreboard nil when
  # unknown. When they are equal, the lines are the team's whole box score.
  def hits_check
    return nil unless game && university

    scoreboard = GameScoreboard.new(game)
    team_hits = game.team0_id == university.id ? scoreboard.top_hits : scoreboard.bottom_hits
    { lines: lines.sum { |line| line.value(:hits).to_i }, scoreboard: team_hits&.to_i }
  end

  # How many of the lines' players are on the guessed game's roster for the
  # university (GameMember, 2021 onward): { on_roster:, lines:, roster: }, nil
  # when that game has no roster.
  def roster_check
    return nil unless game && university

    roster_ids = GameMember.where(game: game, university: university).pluck(:player_id)
    return nil if roster_ids.empty?

    { on_roster: lines.count { |line| roster_ids.include?(line.player_id) }, lines: lines.size, roster: roster_ids.size }
  end

  # The counts a batting side's lines must add up to on the other side's
  # pitching lines: batter's column => pitcher's column, and their names.
  TEAM_CHECKS = {
    strikeouts: [ :strikeouts, "三振", "奪三振" ],
    hits: [ :hits, "安打", "被安打" ],
    walks: [ :walks, "四死球", "与四死球" ]
  }.freeze

  # One count checked across the two sides of the guessed game: the
  # university's batters' total (ours), the other university's pitchers'
  # total, and the batters' total if the lines Scorebook's member page has
  # other values for had those instead (nil when none differ in it).
  TeamCheck = Struct.new(:field, :batting_label, :pitching_label, :batting, :pitching, :batting_with_scorebook, keyword_init: true) do
    def matches?
      batting == pitching
    end

    def scorebook_matches?
      !batting_with_scorebook.nil? && batting_with_scorebook == pitching
    end
  end

  # The TeamChecks of the guessed game, from our batting and pitching lines
  # only, or [] when we have no pitching lines for the other side. They tell
  # which of two differing values fits the game: a batter's strikeouts are the
  # other side's pitchers' strikeouts, and so on.
  def team_checks(states = line_states)
    return [] unless game && university

    batting = BattingLine.where(game: game, university: university)
    pitching = PitchingLine.where(game: game).where.not(university: university)
    return [] unless pitching.exists?

    TEAM_CHECKS.map do |field, (pitching_field, batting_label, pitching_label)|
      ours = batting.sum(field)
      shifts = states.flat_map(&:differences).select { |difference, _, _| difference == field }
      TeamCheck.new(
        field: field, batting_label: batting_label, pitching_label: pitching_label,
        batting: ours, pitching: pitching.sum(pitching_field),
        batting_with_scorebook: (ours + shifts.sum { |_, scorebook, mine| scorebook - mine } if shifts.any?)
      )
    end
  end

  # A note to start the admin's from, worked out from the lines and the team
  # checks: which values differ and which side's the game bears out, or that
  # every line is already in with the same values, or how far the lines
  # gathered are from the team's hits.
  def suggested_note(states = line_states, checks = team_checks(states))
    return nil unless kind == "misfiled_lines" && game

    school = university.short_name
    opponent = (game.team0_id == university.id ? game.team1 : game.team0).short_name
    sentences = []

    if stray?
      twins = lines.map(&:twin_scorebook_game_id).uniq
      sentences << "全員（#{lines.size}人）が同じ日に正しい試合（#{twins.join("、")}）にも登録された行を持つ。" \
        "この行は別の試合の成績表が紛れ込んだものと考えられ、推測した試合に加えるべきではない。"
    end

    states.select { |state| state.state == :imported_differs }.each do |state|
      details = state.differences.map { |field, scorebook, ours| "#{FIELD_NAMES.fetch(field, field)}：Scorebook 選手ページ #{scorebook} / 当サイト #{ours}" }
      sentences << "#{state.line.player.name}の#{details.join("、")}。"
    end

    checks.select(&:batting_with_scorebook).each do |check|
      comparison = "当サイトの値で#{school}打者の#{check.batting_label} #{check.batting} #{check.matches? ? "=" : "≠"} #{opponent}投手の#{check.pitching_label} #{check.pitching}" \
        "（選手ページの値では #{check.batting_with_scorebook}）。"
      verdict = if check.matches? && !check.scorebook_matches?
        "選手ページ側の誤りと考えられる。"
      elsif check.scorebook_matches? && !check.matches?
        "当サイト（Scorebook の試合ページ）側の誤りの可能性がある。"
      else
        "どちらの値が正しいか、この照合では判断できない。"
      end
      sentences << comparison + verdict
    end

    if states.any? && states.all? { |state| state.state == :imported_match }
      sentences << "全員の打撃成績が推測した試合に同じ値で取り込み済み。Scorebook の選手ページだけの誤り。"
    elsif (hits = hits_check) && states.any? { |state| state.state == :to_apply }
      sentences << "集まった行 #{states.size}人、安打の合計 #{hits[:lines]} / スコアボードの H #{hits[:scoreboard] || "不明"}" \
        "#{hits[:lines] == hits[:scoreboard] ? "（全員分そろっている）" : "（まだそろっていない）"}。"
    end

    sentences.join.presence
  end

  # Batting columns' names, for the note.
  FIELD_NAMES = {
    pa: "打席", ab: "打数", hits: "安打", doubles: "二塁打", triples: "三塁打", home_runs: "本塁打", rbi: "打点", runs: "得点",
    strikeouts: "三振", walks: "四死球", sacrifices: "犠打・犠飛", stolen_bases: "盗塁", caught_stealing: "盗塁死",
    gidp: "併殺打", fielding_errors: "失策"
  }.freeze

  # How many batting lines imported from Scorebook we already have for the
  # university in the guessed game (none, if Scorebook files them under another
  # game). Lines added by applying suggestions aren't counted.
  def our_lines_count
    return nil unless game && university

    BattingLine.where(game: game, university: university, fix_suggestion_id: nil).count
  end

  private

  def batting_attributes(line, now)
    counts = ScorebookMemberStats::FIELDS.keys.index_with { |field| line.value(field).to_i }
    total_bases = BattingLine.total_bases_of(**counts.slice(:hits, :doubles, :triples, :home_runs))

    counts.merge(
      game_id: game.id, player_id: line.player_id, university_id: university.id, fix_suggestion_id: id,
      position: line.position, total_bases: total_bases, created_at: now, updated_at: now
    )
  end
end
