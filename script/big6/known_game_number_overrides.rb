# Shared between game.rb (which should NOT reassign game_number for these —
# leave it to fix_duplicate_game_numbers.rb) and fix_duplicate_game_numbers.rb
# itself (which applies the override). See fix_duplicate_game_numbers.rb for
# the full explanation of why these exist.
KNOWN_GAME_NUMBER_OVERRIDES = {
  1963110401 => 4,
  1951061901 => 3,
  1955101801 => 3,
  1952092301 => 3,
  1949102402 => 3,
  1976051001 => 3,
  1948061101 => 4,
  1949052202 => 3,
  1955050901 => 3,
  1995052201 => 4,
  1959111201 => 3,
  1990051501 => 4,
  1957091502 => 4
}.freeze unless defined?(KNOWN_GAME_NUMBER_OVERRIDES)
