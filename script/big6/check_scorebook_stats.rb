# Checks our players' batting lines against Scorebook's own per-player lines
# (its member pages), game by game, and lists what differs (ScorebookStatsCheck
# explains the kinds). One request per player, one second apart; nothing is
# changed.
#
# A game we have no box score for at all (no_stats) is only listed: that is a
# game not imported yet, or one Scorebook's game page has no box score for, not
# a difference in what was imported.
#
# Differences listed in script/big6/scorebook_stats_known_differences.txt are
# known (Scorebook's own errors, or ours not fixed yet) and only counted. Any
# other is new: the run lists them and exits with status 1, so a run after an
# import tells whether it brought anything unexpected. UPDATE_KNOWN=1 adds the
# new ones to the file instead, after they have been looked at.
#
# Which players:
#   (default)   those on Scorebook's batting records page (about 80)
#   IDS=20164001,19922005   these Scorebook ids
#   ALL=1       everyone with a batting line (thousands: hours)
# FROM_DATE / TO_DATE (YYYY-MM-DD) limit the games compared.
#
# Run with: bin/rails runner script/big6/check_scorebook_stats.rb
#           IDS=20164001 bin/rails runner script/big6/check_scorebook_stats.rb
#           FROM_DATE=2026-09-01 ALL=1 bin/rails runner script/big6/check_scorebook_stats.rb
#
# Like the imports, it stops cleanly (exit status 75) if it grows more than
# MEMORY_GROWTH_LIMIT_MB (default 150): the machine is shared with the web server.

KNOWN_FILE = File.expand_path("scorebook_stats_known_differences.txt", __dir__)
SLEEP_SECONDS = 1

known = File.exist?(KNOWN_FILE) ? File.readlines(KNOWN_FILE).map { |line| line.sub(/#.*/, "").strip }.reject(&:empty?).to_set : Set.new

players = if ENV["IDS"]
  Player.where(scorebook_id: ENV["IDS"].split(",").map(&:to_i))
elsif ENV["ALL"]
  Player.where(id: BattingLine.select(:player_id))
else
  ids = ScorebookStatsCheck.record_holder_ids
  abort "couldn't read Scorebook's records page" if ids.empty?
  sleep SLEEP_SECONDS
  Player.where(scorebook_id: ids)
end
players = players.order(:scorebook_id).to_a

from = ENV["FROM_DATE"].presence && Date.parse(ENV["FROM_DATE"])
to = ENV["TO_DATE"].presence && Date.parse(ENV["TO_DATE"])
check = ScorebookStatsCheck.new(dates: (from || to) ? (from || Date.new(1900))..(to || Date.new(9999)) : nil)

memory_limit_mb = ENV.fetch("MEMORY_GROWTH_LIMIT_MB", 150).to_i
guard = MemoryGuard.new(growth_limit_mb: memory_limit_mb)

puts "#{players.size} players to check (about #{(players.size / 60.0).ceil} minutes)"
new_differences = []
no_stats = []
known_count = Hash.new(0)
unreadable = []

players.each_with_index do |player, index|
  differences = check.call(player)
  sleep SLEEP_SECONDS
  if differences.nil?
    unreadable << player
    next
  end

  differences.each do |difference|
    if difference.kind == "no_stats"
      no_stats << difference
    elsif known.include?(difference.key)
      known_count[difference.kind] += 1
    else
      new_differences << difference
    end
  end

  if (index + 1) % 20 == 0
    puts "#{index + 1}/#{players.size} new differences so far: #{new_differences.size}"
    if index + 1 < players.size && guard.exceeded?
      puts "stopping to avoid running out of memory: it has grown #{guard.growth_mb}MB (limit #{memory_limit_mb}MB). Use IDS= to check the rest."
      exit 75
    end
  end
end

puts
puts "known differences: #{known_count.empty? ? "none" : known_count.map { |kind, n| "#{kind} #{n}" }.join(", ")}"
puts "not recorded by Scorebook, 0 here (not differences): #{check.unknown_as_zero.map { |field, n| "#{field} #{n}" }.join(", ").presence || "none"}"
puts "Scorebook's page couldn't be read for: #{unreadable.map(&:scorebook_id).join(", ")}" if unreadable.any?
if no_stats.any?
  games = no_stats.map { |difference| [ difference.scorebook_game_id, difference.played_on ] }.uniq
  puts "games with no box score here (not imported yet, or none on Scorebook's game page), not counted as differences: #{games.size}"
  games.sort_by(&:last).first(20).each { |game_id, played_on| puts "  #{game_id} #{played_on}" }
  puts "  ... and #{games.size - 20} more" if games.size > 20
end
puts "new differences: #{new_differences.size}"
new_differences.group_by(&:kind).each do |kind, differences|
  puts "== #{kind} (#{differences.size})"
  differences.each { |difference| puts "  #{difference}" }
end

if new_differences.any? && ENV["UPDATE_KNOWN"]
  File.open(KNOWN_FILE, "a") { |file| new_differences.each { |difference| file.puts(difference.to_s) } }
  puts "added #{new_differences.size} to #{File.basename(KNOWN_FILE)}"
elsif new_differences.any?
  exit 1
end
