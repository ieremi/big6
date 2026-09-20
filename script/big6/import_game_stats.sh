#!/bin/sh
# Runs import_game_stats.rb to the end, starting it again each time it stops
# because it grew too much (exit status 75). A fresh process starts from the
# memory of a freshly booted app, and games already fetched are skipped, so
# this can run for hours without the process growing past its limit.
#
#   nohup script/big6/import_game_stats.sh > /tmp/import_stats.log 2>&1 &
#
# FROM_YEAR, TO_YEAR, FORCE and MEMORY_GROWTH_LIMIT_MB pass through as usual.
cd "$(dirname "$0")/../.." || exit 1

while :; do
  bin/rails runner script/big6/import_game_stats.rb
  status=$?
  [ "$status" -eq 75 ] || exit "$status"
  echo "restarting the import after a memory stop"
done
