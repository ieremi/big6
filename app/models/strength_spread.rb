# How far apart the six universities' strengths (TeamStrength) were at the end
# of each season, for the article on the seasons where they were closest and
# furthest apart (/articles/strength-spread).
#
# The spread is the variance of the six strength scores after the season's last
# game: the mean of the squares of each score's distance from their mean. It is
# taken on the score, not on the chance of beating an average side, as the score
# is what the chances are worked out from (a chance is the logistic of the score
# less the mean, so the score less the mean is the chance's logit). Also without
# 東大, whose weakness makes most of the spread in most seasons.
#
# Only seasons over, of the league's own games, with all of the last
# TeamStrength::PAST_SEASONS seasons played (TeamStrength#full_history?): the
# strength leans on those seasons, and with fewer behind it (before about 1950,
# Scorebook's games starting in 1938 and the war stopping the league) every
# university looks closer to .500 than it was. As the strength leans on them,
# the spread says more about how far apart the universities had been over some
# five years than about the one season.
#
# Each season is cached on its own until a game of it or of the seasons it
# leans on changes (one multi-read): the hourly sync of the season being
# played only works that one out again, not the ~150 others, which take
# seconds together.
class StrengthSpread
  # One season: its spread, its spread without 東大, and each university's
  # chance of beating an average side at its end.
  Row = Struct.new(:season, :variance, :variance_without_tokyo, :chances, keyword_init: true)

  # Rows of every season that qualifies, oldest first.
  def self.rows
    seasons = Season.select(:id, :year, :term).to_a.sort_by { |season| [ season.year, season.term == "spring" ? 0 : 1 ] }
    updated = Game.group(:season_id).maximum(:updated_at)
    keys = seasons.each_with_index.to_h do |season, index|
      leaned_on = seasons[[ index - TeamStrength::PAST_SEASONS, 0 ].max..index].filter_map { |each| updated[each.id] }
      [ [ "strength_spread/v1", season.id, leaned_on.max.to_i, TeamStrength::PAST_WEIGHT, TeamStrength::CURRENT_WEIGHT ].join("/"), season ]
    end

    cached = Rails.cache.fetch_multi(*keys.keys, expires_in: 1.week) { |key| row_of(keys.fetch(key)) || false }
    universities = University.all.index_by(&:id)
    keys.filter_map do |key, season|
      next unless (row = cached.fetch(key))

      variance, without, chances = row
      Row.new(season: season, variance: variance, variance_without_tokyo: without, chances: chances.to_h { |id, chance| [ universities.fetch(id), chance ] })
    end
  end

  # The mean of the squares of the values' distances from their mean.
  def self.variance(values)
    mean = values.sum / values.size
    values.sum { |value| (value - mean)**2 } / values.size
  end

  # [variance, variance without 東大, [[university id, chance], ...]] of the season
  # in plain values, for the cache; nil when it doesn't qualify.
  def self.row_of(season)
    strength = TeamStrength.new(season)
    return nil unless strength.applicable? && strength.full_history?
    return nil unless Season.select(:id, :scorebook_games).find(season.id).finished?

    _, chances = strength.points.last
    return nil unless chances && chances.size == 6

    logits = chances.transform_values { |chance| Math.log(chance / (1 - chance)) }
    others = logits.reject { |university, _| university.slug == "tokyo" }.values
    [ variance(logits.values), variance(others), chances.map { |university, chance| [ university.id, chance ] } ]
  end
end
