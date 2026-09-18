class SitemapsController < ApplicationController
  CACHE_EXPIRY = 12.hours

  Entry = Struct.new(:loc, :lastmod, :changefreq, :priority, keyword_init: true)

  def show
    cache_key = "sitemap_entries/v1/#{Game.maximum(:updated_at)&.to_i}/#{Game.count}/#{Season.maximum(:updated_at)&.to_i}"
    @entries = Rails.cache.fetch(cache_key, expires_in: CACHE_EXPIRY) { build_entries }

    render layout: false
  end

  private

  def build_entries
    universities = University.order(:position).to_a
    seasons = Season.order(:year, :term).to_a
    games = Game.includes(:team0, :team1).order(:played_on, :game_number).to_a
    LiteSeasonPreload.attach(games)

    entries = [
      Entry.new(loc: root_url, changefreq: "daily", priority: "1.0"),
      Entry.new(loc: seasons_url, changefreq: "weekly", priority: "0.8"),
      Entry.new(loc: matchups_url, changefreq: "weekly", priority: "0.8"),
      Entry.new(loc: games_url, changefreq: "daily", priority: "0.8"),
      Entry.new(loc: universities_url, changefreq: "weekly", priority: "0.6"),
      Entry.new(loc: api_docs_url, changefreq: "monthly", priority: "0.3")
    ]

    universities.each do |u|
      entries << Entry.new(loc: university_url(u.slug), changefreq: "weekly", priority: "0.6")
    end

    seasons.each do |s|
      entries << Entry.new(loc: season_url(s.year, s.term), lastmod: s.updated_at, changefreq: "weekly", priority: "0.7")
    end

    universities.combination(2).each do |a, b|
      entries << Entry.new(loc: matchup_url(a.slug, b.slug), changefreq: "monthly", priority: "0.5")
    end

    games.each do |g|
      entries << Entry.new(
        loc: matchup_game_url(g.team0.slug, g.team1.slug, g.season.year, g.season.term, g.game_number),
        lastmod: g.updated_at,
        changefreq: "monthly",
        priority: "0.4"
      )
    end

    entries
  end
end
