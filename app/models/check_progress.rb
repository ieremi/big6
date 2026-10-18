# How far the two checks of the data have got, for the admin dashboard: the
# nightly check of players' batting lines against Scorebook
# (CheckScorebookStatsJob), which goes through every player with batting lines
# in turn and then starts again, and the review of the games data check
# (GameDataCheck), whose findings an admin marks fine one by one.
class CheckProgress
  # How many players the nightly job checks in a night.
  PLAYERS_PER_NIGHT = CheckScorebookStatsJob::BATCH_SIZE * CheckScorebookStatsJob::RUNS_PER_NIGHT

  # The players due checks (everyone with batting lines), and how many of them
  # have been checked at least once.
  def players_total
    @players_total ||= players.count
  end

  def players_checked
    @players_checked ||= checks.count
  end

  def players_remaining
    players_total - players_checked
  end

  # Nights until everyone has been checked once (0 once they all have).
  def nights_remaining
    (players_remaining.to_f / PLAYERS_PER_NIGHT).ceil
  end

  # Nights a whole round takes, everyone once.
  def nights_per_round
    (players_total.to_f / PLAYERS_PER_NIGHT).ceil
  end

  # The oldest and the latest check: once everyone has been checked, the oldest
  # is where the next round has got to.
  def oldest_check_at
    checks.minimum(:checked_at)
  end

  def latest_check_at
    checks.maximum(:checked_at)
  end

  def checked_in_last_day
    checks.where(checked_at: 24.hours.ago..).count
  end

  # The games data check, per kind (in GameDataCheck::KINDS order, only kinds
  # with findings): [kind, findings, of them reviewed].
  def game_check_counts
    @game_check_counts ||= begin
      reviewed = GameCheckReview.pluck(:key).to_set
      game_check_keys.map { |kind, keys| [ kind, keys.size, keys.count { |key| reviewed.include?(key) } ] }
    end
  end

  def game_findings_total
    game_check_counts.sum { |_, total, _| total }
  end

  def game_findings_reviewed
    game_check_counts.sum { |_, _, reviewed| reviewed }
  end

  private

  def players
    Player.where(id: BattingLine.select(:player_id))
  end

  def checks
    ScorebookStatsPlayerCheck.where(player_id: BattingLine.select(:player_id))
  end

  # { kind => the keys of its findings }. Running the check goes through every
  # game, so its keys are cached until the games change; which of them are
  # reviewed is looked up afresh each time.
  def game_check_keys
    cache_key = [ "check_progress/game_check_keys", Game.maximum(:updated_at)&.to_f, Game.count ].join("/")
    Rails.cache.fetch(cache_key, expires_in: 1.day) do
      GameDataCheck.new.findings.group_by(&:kind).transform_values { |findings| findings.map(&:key) }
    end
  end
end
