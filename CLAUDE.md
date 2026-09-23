# CLAUDE.md

A Rails 8.1 site (plus a JSON Web API) for the Tokyo Big6 Baseball League (東京六大学野球): every game since 1925, seasons and standings, head-to-head matchups, players and their stats, rankings, and generated OG images. Most of the data comes from scraping outside sources. The UI text is Japanese, and so are many stored values (for example the game statuses).

## Stack

- Ruby 3.4 (`.ruby-version`), Rails 8.1, PostgreSQL, Puma
- Hotwire: Turbo plus Stimulus through importmap. There is no JS build step or `package.json`; Stimulus controllers are in `app/javascript/controllers/`.
- Propshaft assets and a single stylesheet, `app/assets/stylesheets/application.css`
- Solid Queue, Solid Cache and Solid Cable. Each one uses its own database in production.
- `ruby-vips` (through `image_processing`) renders the OG images. Japanese text needs a CJK font, which both Dockerfiles install (`fonts-ipafont-gothic`).
- Nokogiri and `Net::HTTP` for the scrapers. There is no HTTP client gem.
- Minitest with YAML fixtures. RuboCop uses `rubocop-rails-omakase`.

## Commands

```sh
bin/setup --skip-server          # install gems, prepare the DB (the devcontainer runs this)
bin/dev                          # = bin/rails server
bin/rails test                   # the whole suite (~415 tests, runs in parallel)
bin/rails test test/models/game_test.rb:42
bin/rubocop                      # add -a to autocorrect
bin/ci                           # everything in config/ci.rb: rubocop, audits, brakeman, tests, seeds
bin/rails runner script/big6/<script>.rb   # data import and maintenance (see below)
```

In the devcontainer, `DB_HOST=postgres` points `config/database.yml` at the compose Postgres (user and password are `postgres`). `db/seeds.rb` creates the 6 universities and every Season from 1925 through 2026. Games, players and stats are not seeded; they come from the import scripts.

## Domain model

- **University**: the 6 teams. Views and the API refer to them by `slug` (`waseda keio meiji hosei tokyo rikkio`; Rikkyo's slug is spelled **`rikkio`**). `position` sets the display order. Colours and initials are constants in the model.
- **Season**: `year` plus `term` (`spring` or `autumn`). It holds large JSONB caches of the raw Scorebook data (`scorebook_data`, `scorebook_games`, tens to hundreds of KB per season). Don't load them in bulk: use `LiteSeasonPreload` or `select` only the columns you need.
- **Game**: `team0` and `team1` (team0 = top/visitor as Scorebook records it), `game_number` (the round: 1回戦, 2回戦, ...), scores, attendance, weather, video URL, and `league_official_data` (JSONB, a provisional box score from big6.gr.jp).
  - `game_status` is an enum whose stored values are Japanese: `scheduled 試合前`, `in_progress 試合中`, `finished 試合終了`, `cancelled 中止`, `no_game ノーゲーム`.
  - A game that wasn't held (`not_held?`) has **no `game_number`** and no score; a `before_validation` callback clears the number. `Game.record_cancellation` is the single path for recording one.
  - `counted_in_stats: false` marks the 優勝決定戦 playoffs. They are shown but left out of player totals and rankings.
- **Player**: from Scorebook's 名鑑. Keyed by `scorebook_id`, which is also the id used in `/players/:id` URLs and the API. The table also holds staff (監督, 部長, ...), not just players.
- **GameMember** (roster per game, 2021 onward), **BattingLine**, **PitchingLine** (per-game box score; innings are stored as `outs`).
- **PrimeMinisterTerm** and **GdpPerCapitaYear**: reference data shown on season pages (from Wikidata and the World Bank).

Most of `app/models/` is plain Ruby rather than ActiveRecord: scrapers and importers, view-model calculators (`Standings`, `Matchup`, `TeamRecord`, `PlayerStats`, `PlayerRanking`, `PlayerSearch`, `SeasonWeeks`, `GameScoreboard`, ...) and OG image renderers (`OgImage` subclasses; `OgImages` is the shared entry point for both the site and the API). Every class opens with a comment explaining why it exists. Read that comment before changing the class.

## Data sources and syncing

| Source | Classes | What it provides |
|---|---|---|
| big6scorebook.jp (the canonical source) | `ScorebookSync`, `PlayerSync`, `GameStatsImport`, `GameMemberImport`, `script/big6/scorebook/*`, `script/big6/game.rb` | games, scores, innings, players, box scores, rosters |
| big6.gr.jp (the official league site) | `LeagueOfficialScheduleScraper`, `LeagueOfficialGameScraper` (read back by `LeagueOfficialScoreboard` and `LeagueOfficialLineup`) | newly added 3回戦 games, cancellations, provisional box scores and lineups before Scorebook publishes |
| sportsbull.jp | `SportsbullVideoScraper` | full-match replay links (2023 onward) |
| JMA (気象庁) | `JmaWeatherScraper` | daily Tokyo weather |
| Wikidata, World Bank | `ReferenceDataSync` | Prime Ministers, GDP per capita |

Recurring jobs (`config/recurring.yml`, production only):
- `SyncRecentGamesJob` runs hourly. It covers games from the last 3 days: schedule, videos, weather, Scorebook, provisional data and player box scores.
- `RefreshLiveScoreboardsJob` runs every 5 minutes. It does nothing unless a game is under way or due to have started.

Production runs the Solid Queue supervisor inside Puma (`SOLID_QUEUE_IN_PUMA`).

Scorebook is the source of truth. Provisional data from the league site must never overwrite or regress what Scorebook already has; several recent fixes guarded against exactly that. Scorebook's own data also has known errors, which are corrected at import time: `script/big6/known_game_number_overrides.rb`, `known_team_corrections.rb`, and the round relabelling for replays in `ScorebookSync`.

The scripts in `script/big6/` are run with `bin/rails runner`, and each one documents its env vars in its header. The main ones:
- `full_sync.rb` runs the Scorebook season import in the right order. `FROM_YEAR` and `SEASON_LIMIT` split it into batches.
- `import_players.rb` must run before `import_game_members.rb` and `import_game_stats.rb`.
- `import_game_stats.sh` restarts the stats import each time `MemoryGuard` stops it with exit code 75.
- `update_cancelled_games.rb` and `update_reference_data.rb`.
- `check_scorebook_stats.rb` compares our batting lines with Scorebook's per-player pages and changes nothing. Differences listed in `scorebook_stats_known_differences.txt` count as known; if any others turn up, it exits with status 1.
- Scripts named `fix_*`, `delete_*` and `backfill_*` are one-off data fixes.

## Routes and controllers

- HTML pages: `/games` (search, plus per-team browsing at `/games/:team`), `/seasons/:year/:term` (plus `/standings`), `/matchups/:team0/:team1[/:year[/:term[/:game_number]]]` (a single game page is a matchup URL), `/universities/:slug`, `/players`, `/players/:id`, `/rankings/:kind`.
- Almost every page has a sibling `.../og.png` route that renders its OG image.
- Seasons and games also serve `.ics` calendars (`IcsCalendar`, `IcsGameEvent`), and there is a `/sitemap.xml`.
- The Web API lives under `/api/v1/*` (`Api::V1::BaseController < ActionController::API`). Games are identified by `year/term/team0/team1/round`, never by database id. The API is documented in the page at `/api/docs` (`app/views/api_docs/show.html.erb`, which includes a live sandbox). **Update that page whenever you change the API.**
- The players page and the players API share `PlayerSearch`; the rankings page and the rankings API share `PlayerRanking`. Keep filtering and sorting logic in those models, not in the controllers.
- Tables can be sorted by column, on the server (`GameSortable`, `SortableHelper`, `PlayerSearch`) and in the browser (`sortable_table_controller.js`). Sort and filter state has to survive form resubmits (hidden fields).

## Performance constraints

Production is a single Render instance with 0.5 CPU and 512 MB (`render.yaml`, Singapore), shared by web, jobs and one-off scripts. Keep that in mind:
- Avoid N+1 queries and loading JSONB in bulk. Several classes accept preloaded `games:` or `universities:` for this reason.
- Expensive pages cache their results in `Rails.cache` (sitemap, matchups, ICS, season tags, rankings, player-search counts). Any cache key must vary with every parameter that affects the result. The test environment uses `:null_store`.
- Long scripts should use `MemoryGuard`.
- `config/deploy.yml` and `.kamal/` are leftovers from the Rails template. Deployment is on Render, using the production `Dockerfile`.

## Conventions

- Match the existing comment style: explanatory prose comments above classes and methods that say *why*, often with the Japanese term alongside.
- Commit messages have an imperative, sentence-case subject with no prefix and describe the behaviour from the user's point of view (e.g. "Keep showing the provisional lineup after a game finishes, not just while in progress"). Longer changes get a body explaining the reasoning.
- Tests: `test_helper.rb` provides `stub_method(object, name, callable)`, because Minitest 6 dropped `minitest/mock`. Scraper and sync tests stub the HTTP-fetching methods this way; tests make no real network calls.
- The app's time zone is UTC, but games are played in Tokyo. Code that needs Tokyo dates uses `ActiveSupport::TimeZone["Asia/Tokyo"]` explicitly (see `RefreshLiveScoreboardsJob`).
  - Known flaky test: `test/jobs/refresh_live_scoreboards_job_test.rb:51` builds its games with `Date.current`, which is the UTC date. The test therefore fails between 15:00 and 24:00 UTC, when the Tokyo date is already the next day.
- `bin/rubocop` currently reports some existing offenses. Don't add new ones.
