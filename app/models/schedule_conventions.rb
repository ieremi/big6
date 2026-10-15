# Whether each season's schedule followed the league's conventions (慣例) for
# laying out the cards from the previous season's standings: who opens the
# season, who meets whom in which week. The conventions aren't written rules
# but a pattern read from the schedules; this shows, season by season, where
# it held and where it didn't.
#
# W K M H R T are 早慶明法立東; "MHRT" the four universities other than 早慶,
# ranked among themselves by the previous season. Weeks are CardOrders'
# (a card in the week its first game was scheduled; the 早慶戦 alone last).
#
# Each rule's result for a season is :followed, :broken, nil when its
# condition doesn't hold (or there is no previous season to go by), or
# :unknown when the previous standings have a tie the rule would need to
# break. Seasons with all their cards from 1950 on (CardOrders) whose
# previous season is ranked (StandingsOrders) are checked.
class ScheduleConventions
  Rule = Struct.new(:key, :week, :text, :check, keyword_init: true)
  # A season checked: the previous season's places and each rule's result.
  Result = Struct.new(:season, :previous, :results, keyword_init: true)

  # Raised by a rule needing two universities that were level the previous season.
  class Tied < StandardError; end

  RULES = [
    Rule.new(key: "m1", week: 1, text: "明大が前季1位なら、明大対（明法立東のなかの前季4位）",
      check: ->(c) { c.week_has_card?(1, :m, c.mhrt(4)) if c.rank(:m) == 1 }),
    Rule.new(key: "wk2", week: 1, text: "早慶のどちらかが前季2位なら、2位でない方が出る",
      check: lambda { |c|
        second = %i[w k].select { |u| c.rank(u) == 2 }
        next nil if second.empty?
        raise Tied if second.size > 1

        c.week_has?(1, (%i[w k] - second).first)
      }),
    Rule.new(key: "wk3", week: 1, text: "早慶がともに前季3位以下なら、上位の方が出る",
      check: lambda { |c|
        next nil unless c.rank(:w) >= 3 && c.rank(:k) >= 3
        raise Tied if c.rank(:w) == c.rank(:k)

        c.week_has?(1, c.rank(:w) < c.rank(:k) ? :w : :k)
      }),
    Rule.new(key: "wk1", week: 1, text: "早慶のどちらかが前季1位なら、早慶とも出て、明法立東のなかの前季2位は出ない",
      check: lambda { |c|
        next nil unless c.rank(:w) == 1 || c.rank(:k) == 1

        c.week_has?(1, :w) && c.week_has?(1, :k) && !c.week_has?(1, c.mhrt(2))
      }),
    Rule.new(key: "first", week: 1, text: "前季1位は必ず出る",
      check: ->(c) { c.week_has?(1, c.first_place) }),
    Rule.new(key: "w2", week: 2, text: "明法立東のなかの前季2位対3位",
      check: ->(c) { c.week_has_card?(2, c.mhrt(2), c.mhrt(3)) }),
    Rule.new(key: "w4", week: 4, text: "第1週と同じ顔ぶれ",
      check: ->(c) { c.teams_of(4) == c.teams_of(1) }),
    Rule.new(key: "w5", week: 5, text: "第2週と同じ顔ぶれ",
      check: ->(c) { c.teams_of(5) == c.teams_of(2) }),
    Rule.new(key: "w6", week: 6, text: "早慶が出て、明法立東のなかの前季1位・2位を迎え撃つ",
      check: ->(c) { c.opponents_of(6, %i[w k]) == [ c.mhrt(1), c.mhrt(2) ].to_set }),
    Rule.new(key: "w7", week: 7, text: "明法立東が出て、この4校のなかの前季1位対2位、3位対4位",
      check: ->(c) { c.week_has_card?(7, c.mhrt(1), c.mhrt(2)) && c.week_has_card?(7, c.mhrt(3), c.mhrt(4)) }),
    Rule.new(key: "mhrt", week: nil, text: "早慶のどちらかが前季1位なら、明法立東だけが出る週を3週以上つくる",
      check: ->(c) { c.mhrt_only_weeks >= 3 if c.rank(:w) == 1 || c.rank(:k) == 1 })
  ].freeze

  SLUGS = { w: "waseda", k: "keio", m: "meiji", h: "hosei", r: "rikkio", t: "tokyo" }.freeze

  def self.all
    Rails.cache.fetch([ "schedule_conventions/v1", Game.maximum(:updated_at)&.to_i, Game.count ]) { new.seasons }
  end

  # The result for one season (on its page), or nil when it isn't checked:
  # worked out from its games and the previous season's alone, and cached
  # until either changes.
  def self.for(season)
    previous = season.previous or return nil
    updated = Game.where(season_id: [ season.id, previous.id ]).maximum(:updated_at)
    Rails.cache.fetch([ "schedule_conventions/season/v1", season.id, updated&.to_i ]) { new.result_for(season, previous) }
  end

  def result_for(season, previous)
    weeks = CardOrders.new.weeks_by_season([ season ])[season] or return nil
    places = StandingsOrders.new.places_by_season([ previous ])[previous] or return nil

    check = Check.new(weeks, places)
    Result.new(season: season, previous: places, results: RULES.to_h { |rule| [ rule.key, check.result(rule) ] })
  end

  def seasons
    places = StandingsOrders.new.places_by_season.transform_keys(&:id)
    previous_ids = Season.select(:id, :year, :term).to_h { |season| [ [ season.year, season.term ], season.id ] }

    CardOrders.new.weeks_by_season.filter_map do |season, weeks|
      previous_key = season.term == "autumn" ? [ season.year, "spring" ] : [ season.year - 1, "autumn" ]
      previous = places[previous_ids[previous_key]] or next

      check = Check.new(weeks, previous)
      Result.new(season: season, previous: previous, results: RULES.to_h { |rule| [ rule.key, check.result(rule) ] })
    end
  end

  # The facts the rules ask about one season, given its weeks and the
  # previous season's places.
  class Check
    def initialize(weeks, previous_places)
      @weeks = weeks
      @rank = {}
      above = 0
      previous_places.each do |universities|
        universities.each { |university| @rank[university.slug] = above + 1 }
        above += universities.size
      end
      @places = previous_places
    end

    def result(rule)
      outcome = rule.check.(self)
      outcome.nil? ? nil : (outcome ? :followed : :broken)
    rescue Tied
      :unknown
    end

    # The previous season's rank of a university (:w, :k, ...); tied ones share it.
    def rank(letter)
      @rank.fetch(SLUGS.fetch(letter))
    end

    # The previous season's first place, a letter.
    def first_place
      raise Tied if @places.first.size > 1

      letter(@places.first.first)
    end

    # The nth (1–4) of 明法立東 by the previous season, a letter.
    def mhrt(nth)
      ranked = %i[m h r t].sort_by { |l| rank(l) }
      raise Tied if ranked.count { |l| rank(l) == rank(ranked[nth - 1]) } > 1

      ranked[nth - 1]
    end

    def week_has?(week, letter)
      teams_of(week).include?(letter)
    end

    def week_has_card?(week, a, b)
      cards_of(week).include?([ a, b ].to_set)
    end

    # The set of universities playing in a week.
    def teams_of(week)
      cards_of(week).flat_map(&:to_a).to_set
    end

    # The opponents of the given universities in a week, each of them having to play.
    def opponents_of(week, letters)
      cards = cards_of(week)
      return nil unless letters.all? { |l| cards.any? { |card| card.include?(l) } }

      cards.flat_map { |card| (card & letters.to_set).any? ? (card - letters.to_set).to_a : [] }.to_set
    end

    def mhrt_only_weeks
      @weeks.count { |cards| cards.all? { |pair| pair.all? { |u| %w[meiji hosei rikkio tokyo].include?(u.slug) } } }
    end

    private

    def cards_of(week)
      Array(@weeks[week - 1]).map { |pair| pair.map { |university| letter(university) }.to_set }
    end

    def letter(university)
      SLUGS.key(university.slug)
    end
  end
end
