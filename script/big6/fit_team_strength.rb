# Fits the weights of TeamStrength (強さの推移) again, and checks them: a
# logistic regression of whether team0 won on the differences of the two
# sides' win rates (their last TeamStrength::PAST_SEASONS seasons', and this
# season's so far), fitted on the games of the seasons before FIT_UNTIL and
# checked on those from it, against an even chance in every game. Draws are
# left out. No network; prints the weights to put in TeamStrength, which this
# changes nothing of.
#
# Run with: bin/rails runner script/big6/fit_team_strength.rb
#           FIT_UNTIL=2015 bin/rails runner script/big6/fit_team_strength.rb
fit_until = ENV.fetch("FIT_UNTIL", "2010").to_i

rows = Season.order(:year, :term).flat_map do |season|
  strength = TeamStrength.new(season)
  next [] unless strength.applicable?

  strength.each_game_features.filter_map do |game, team0, team1|
    next if game.team0_score == game.team1_score

    [ season.year, [ 1.0, team0[0] - team1[0], team0[1] - team1[1] ], game.team0_score > game.team1_score ? 1 : 0 ]
  end
end
train, test = rows.partition { |year, _, _| year < fit_until }
abort "no games to fit or to check" if train.empty? || test.empty?

sigmoid = ->(z) { 1 / (1 + Math.exp(-z)) }
predict = ->(weights, x) { sigmoid.(x.zip(weights).sum { |a, b| a * b }) }

# Gradient ascent on the log likelihood: three weights over a few thousand games.
weights = [ 0.0, 0.0, 0.0 ]
500.times do
  gradient = [ 0.0, 0.0, 0.0 ]
  train.each do |_, x, won|
    error = won - predict.(weights, x)
    x.each_with_index { |value, j| gradient[j] += error * value }
  end
  weights = weights.each_with_index.map { |weight, j| weight + 4.0 * gradient[j] / train.size }
end

log_loss = lambda do |data, &chance|
  -data.sum { |_, x, won| p = chance.(x).clamp(1e-6, 1 - 1e-6); won == 1 ? Math.log(p) : Math.log(1 - p) } / data.size
end
hit_rate = ->(data, &chance) { data.count { |_, x, won| (chance.(x) >= 0.5 ? 1 : 0) == won }.fdiv(data.size) }

puts "fitted on #{train.size} games before #{fit_until}, checked on #{test.size} from it"
puts format("weights: intercept %.3f, past %.3f, this season %.3f", *weights)
puts format("in TeamStrength:     past %.2f, this season %.2f", TeamStrength::PAST_WEIGHT, TeamStrength::CURRENT_WEIGHT)
puts format("log loss %.4f (an even chance: %.4f), %.1f%% of games called right",
  log_loss.(test) { |x| predict.(weights, x) }, Math.log(2), hit_rate.(test) { |x| predict.(weights, x) } * 100)
