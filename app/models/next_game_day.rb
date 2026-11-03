# The next day with games (今日の試合), for the home page: today's games, or
# the next day's within a week, each with what a fan looks up before it — when
# it starts, who starts on the mound (先発), who has come into the starting
# lineup since the side's previous game (RosterDiff), and the runs of seasons in
# a row the card has at stake (StreakRecords: 「明大が勝ち点を取れば立大から10季連続」), and
# the 勝ち点 it would bring back after a long while (「東大が勝ち点を取れば早大から56季ぶり」).
#
# The lineup is Scorebook's (GameMember) once it has one, or before then the
# league site's provisional one (LeagueOfficialLineup), which is up some half
# an hour before the first pitch (RefreshLiveScoreboardsJob reads it then).
# Days are Tokyo's, where the games are played (the app's time zone is UTC).
class NextGameDay
  DAYS_AHEAD = 7

  # A game of the day: the game, its scheduled start (「13:00」), the starting
  # pitcher and the new starters of each side (by university id; a pitcher or a
  # starter is a GameMember, or a LeagueOfficialLineup entry, whose player may be
  # nil), and the card's runs and comebacks at stake.
  Entry = Data.define(:game, :start_time, :starting_pitchers, :new_starters, :streaks, :comebacks)

  def initialize(today: ActiveSupport::TimeZone["Asia/Tokyo"].today)
    @today = today
  end

  # The day, or nil when there are no games in the week ahead.
  def date
    return @date if defined?(@date)

    @date = Game.where(played_on: @today..(@today + DAYS_AHEAD - 1)).minimum(:played_on)
  end

  def today?
    date == @today
  end

  # The day's games in the order they are played, each an Entry.
  def entries
    return [] unless date

    @entries ||= begin
      games = Game.where(played_on: date).includes(:season, :team0, :team1).order(:game_order, :id).to_a
      at_stake = ->(list) { list.select { |record| record.status == :at_stake && record.kind.key == :card } }
      records = games.map(&:season).uniq.to_h { |season| [ season.id, StreakRecords.new(season) ] }
      games.map do |game|
        season = records.fetch(game.season_id)
        entry_for(game, at_stake.(season.records), at_stake.(season.comebacks))
      end
    end
  end

  private

  def entry_for(game, at_stake, comebacks)
    return Entry.new(game:, start_time: nil, starting_pitchers: {}, new_starters: {}, streaks: [], comebacks: []) if game.not_held?

    members = game.game_members.includes(:player).group_by(&:university_id)
    lineup = LeagueOfficialLineup.new(game) if members.blank?
    source = members.presence || lineup&.by_university || {}
    diffs = RosterDiff.for_game(game, members_by_university: members, official_lineup: lineup)

    pitchers = source.transform_values { |list| list.find { |member| member.fielding_position == "投" } }.compact
    # The starting pitcher is a new starter to RosterDiff every time (with a designated hitter); they are told as 先発.
    new_starters = diffs.to_h do |university_id, diff|
      [ university_id, diff.new_starters.map(&:player) - [ pitchers[university_id]&.player ] ]
    end
    Entry.new(
      game:,
      start_time: EstimatedGameSchedule.new(game).scheduled_start_time,
      starting_pitchers: pitchers,
      new_starters: new_starters.reject { |_, players| players.empty? },
      streaks: at_stake.select { |record| card_of?(record, game) },
      comebacks: comebacks.select { |comeback| card_of?(comeback, game) }
    )
  end

  # Whether a card's run or comeback is the game's card.
  def card_of?(record, game)
    [ record.university.id, record.opponent.id ].sort == [ game.team0_id, game.team1_id ].sort
  end
end
