# 2027年春季の日程の予想, for the article at /articles/schedule-2027-spring and its
# calendar (.ics): the cards week by week as the schedule conventions
# (ScheduleConventions) lay them out from 2026 autumn's standings, worked out by
# hand on 2026-11-09 (the article says how), with 早大 playing in the first week.
# swapped gives the other case, 慶大 first: 早慶 trade places in weeks 1–6.
#
# A card's 1回戦 is on the week's Saturday and its 2回戦 on the Sunday; a 3回戦,
# the Monday after, is played only at one win each, so the calendar leaves it
# out. The week's first card in WEEKS (and the article's table) is taken as
# Saturday's 第1試合, 11:00 to 13:30, and the second as the 第2試合, 14:00 to 16:30;
# on Sunday the order turns round and each card's sides swap, as the league does;
# a day shared with the professionals (プロ併用日, not yet known) starts at 10:00
# instead, as the article says. The 早慶戦, alone on its days, is all-day.
class SchedulePrediction2027Spring
  # [hour, minute] of the start and the end of the day's first and second game.
  GAME_TIMES = [ [ [ 11, 0 ], [ 13, 30 ] ], [ [ 14, 0 ], [ 16, 30 ] ] ].freeze

  # [the week's Saturday, its cards as pairs of slugs (which side bats first isn't known)]
  WEEKS = [
    [ Date.new(2027, 4, 10), [ %w[meiji tokyo], %w[waseda rikkio] ] ],
    [ Date.new(2027, 4, 17), [ %w[hosei rikkio], %w[keio tokyo] ] ],
    [ Date.new(2027, 4, 24), [ %w[keio hosei], %w[waseda meiji] ] ],
    [ Date.new(2027, 5, 1), [ %w[waseda tokyo], %w[meiji rikkio] ] ],
    [ Date.new(2027, 5, 8), [ %w[hosei tokyo], %w[keio rikkio] ] ],
    [ Date.new(2027, 5, 15), [ %w[waseda hosei], %w[keio meiji] ] ],
    [ Date.new(2027, 5, 22), [ %w[meiji hosei], %w[rikkio tokyo] ] ],
    [ Date.new(2027, 5, 29), [ %w[waseda keio] ] ]
  ].freeze

  # A week: its number, Saturday, and cards (pairs of Universities).
  Week = Data.define(:number, :starts_on, :cards)

  def initialize(swapped: false)
    @swapped = swapped
  end

  def weeks
    universities = University.all.index_by(&:slug)
    WEEKS.each_with_index.map do |(starts_on, cards), index|
      cards = cards.map { |pair| pair.map { |slug| universities.fetch(swap(slug, index)) } }
      Week.new(number: index + 1, starts_on:, cards:)
    end
  end

  def to_ics
    calendar = IcsCalendar.new(name: "2027年春季リーグ戦（予想）")
    tokyo = ActiveSupport::TimeZone["Asia/Tokyo"]
    weeks.each do |week|
      week.cards.each_with_index do |(a, b), order|
        [ [ 1, week.starts_on ], [ 2, week.starts_on + 1 ] ].each do |round, day|
          # A day of two cards: on Saturday the first card first, and on Sunday the other way round, each card's
          # sides swapped too (明大–東大 and 早大–立大, then 立大–早大 and 東大–明大); the 早慶戦 alone, all-day.
          slot = round == 1 ? order : week.cards.size - 1 - order
          first, second = round == 1 ? [ a, b ] : [ b, a ]
          start, finish = (GAME_TIMES[slot] if week.cards.size > 1)&.map { |hour, minute| tokyo.local(day.year, day.month, day.day, hour, minute) }
          calendar.add_event(
            uid: "prediction-2027-spring-#{a.slug}-#{b.slug}-#{round}@big6",
            summary: "【予想】#{first.short_name} vs #{second.short_name}#{IcsGameEvent::CIRCLED_DIGITS[round - 1]}",
            start_time: start, end_time: finish, all_day_date: (day unless start),
            location: StadiumLocation.for("神宮球場"),
            description: "2027年春季リーグ戦 第#{week.number}週 #{round}回戦（予想）。日程の慣例から予想したもので、連盟の発表ではありません。1勝1敗なら翌日に3回戦。"
          )
        end
      end
    end
    calendar.to_ics
  end

  private

  # 早慶 trade places in weeks 1–6 when 慶大 plays first (the 早慶戦 stays).
  def swap(slug, index)
    return slug unless @swapped && index < 6

    { "waseda" => "keio", "keio" => "waseda" }.fetch(slug, slug)
  end
end
