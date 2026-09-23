# Reports what the checks of our batting lines against Scorebook's own
# per-player lines (its member pages) have found, as recorded in the database
# (ScorebookStatsPlayerCheck, ScorebookStatsDifference). CheckScorebookStatsJob
# does the checking, a few players each run through the small hours; this
# script only reads what it recorded, unless asked to check some players now.
#
# ScorebookStatsCheck explains the kinds of difference. Games we have no box
# score for at all (no_stats) are only counted. Differences marked known (looked
# at: Scorebook's own errors, or ours not fixed yet) are only counted; any other
# is new, and is listed, and makes the script exit with status 1.
#
#   bin/rails runner script/big6/check_scorebook_stats.rb
#
# Check some players now, recording the result as the job does (one request a
# second; nothing else is changed), then report:
#   CHECK=1 IDS=20164001,19922005 bin/rails runner script/big6/check_scorebook_stats.rb
#   CHECK=1 RECORD_HOLDERS=1 bin/rails runner script/big6/check_scorebook_stats.rb   (Scorebook's records page, about 80)
#
# Mark every new difference known, once they have been looked at:
#   MARK_KNOWN=1 bin/rails runner script/big6/check_scorebook_stats.rb
#
# A check stops cleanly (exit status 75) if it grows more than
# MEMORY_GROWTH_LIMIT_MB (default 150): the machine is shared with the web
# server. What it checked by then is recorded; run it again for the rest.

SLEEP_SECONDS = 1

if ENV["CHECK"]
  ids = if ENV["IDS"]
    ENV["IDS"].split(",").map(&:to_i)
  elsif ENV["RECORD_HOLDERS"]
    ScorebookStatsCheck.record_holder_ids.presence or abort "couldn't read Scorebook's records page"
  else
    abort "CHECK=1 needs IDS= or RECORD_HOLDERS=1 (the nightly job checks everyone)"
  end
  players = Player.where(scorebook_id: ids).order(:scorebook_id).to_a

  memory_limit_mb = ENV.fetch("MEMORY_GROWTH_LIMIT_MB", 150).to_i
  guard = MemoryGuard.new(growth_limit_mb: memory_limit_mb)
  puts "checking #{players.size} players (about #{(players.size / 60.0).ceil} minutes)"

  players.each_with_index do |player, index|
    sleep SLEEP_SECONDS
    ScorebookStatsPlayerCheck.run(player)
    next unless (index + 1) % 20 == 0

    puts "#{index + 1}/#{players.size}"
    if index + 1 < players.size && guard.exceeded?
      puts "stopping to avoid running out of memory: it has grown #{guard.growth_mb}MB (limit #{memory_limit_mb}MB). " \
           "The players checked so far are recorded."
      exit 75
    end
  end
  puts
end

if ENV["MARK_KNOWN"]
  marked = ScorebookStatsDifference.unknown.update_all(known: true, updated_at: Time.current)
  puts "marked #{marked} differences known"
end

due = Player.where(id: BattingLine.select(:player_id)).count
checks = ScorebookStatsPlayerCheck.all
puts "players checked: #{checks.count} of #{due}" \
     "#{", oldest check #{checks.minimum(:checked_at)&.in_time_zone("Asia/Tokyo")&.strftime("%Y-%m-%d %H:%M")}" if checks.exists?}"

unreadable = checks.where(readable: false).includes(:player).map { |check| check.player.scorebook_id }
puts "Scorebook's page couldn't be read at the last check for: #{unreadable.join(", ")}" if unreadable.any?

unknown_as_zero = checks.pluck(:unknown_as_zero).each_with_object(Hash.new(0)) { |counts, sums| counts.each { |field, n| sums[field] += n } }
puts "not recorded by Scorebook, 0 here (not differences): #{unknown_as_zero.map { |field, n| "#{field} #{n}" }.join(", ").presence || "none"}"

no_stats = ScorebookStatsDifference.where(kind: ScorebookStatsDifference::NOT_COUNTED_KINDS).distinct.count(:scorebook_game_id)
puts "games with no box score here (not imported yet, or none on Scorebook's game page): #{no_stats}"

known = ScorebookStatsDifference.counted.where(known: true).group(:kind).count
puts "known differences: #{known.map { |kind, n| "#{kind} #{n}" }.join(", ").presence || "none"}"

new_differences = ScorebookStatsDifference.unknown.includes(:player).order(:kind, :played_on, :key).to_a
puts "new differences: #{new_differences.size}"
new_differences.group_by(&:kind).each do |kind, differences|
  puts "== #{kind} (#{differences.size})"
  differences.each { |difference| puts "  #{difference}" }
end

exit 1 if new_differences.any?
