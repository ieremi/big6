# The sitemap for search engines: /sitemap.xml (which robots.txt names) is a
# sitemap index of three sitemaps, one per kind of page, so Search Console
# reports each kind on its own and no one response grows too large:
#
#   pages    the lists, seasons, universities, matchups, news and the notes for developers
#   games    every game held (a cancelled one has no page of its own)
#   players  every player and staff member's page, the long tail people search
#            for by name (13,000 and more)
#
# Each is cached until what it lists changes.
class SitemapsController < ApplicationController
  CACHE_EXPIRY = 12.hours
  PARTS = %w[pages games players].freeze

  Entry = Struct.new(:loc, :lastmod, :changefreq, :priority, keyword_init: true)

  def index
    @parts = PARTS.map { |part| [ sitemap_part_url(part, format: :xml), lastmod_of(part) ] }
    render layout: false
  end

  def show
    part = params[:part]
    raise ActionController::RoutingError, "no #{part} sitemap" unless PARTS.include?(part)

    @entries = Rails.cache.fetch("sitemap_entries/v5/#{part}/#{version_of(part)}", expires_in: CACHE_EXPIRY) { send("#{part}_entries") }
    render layout: false
  end

  private

  # What a part's cache depends on: it is rebuilt when any of it changes.
  def version_of(part)
    case part
    when "pages" then [ Season.maximum(:updated_at)&.to_i, Season.count, Announcement.maximum(:updated_at)&.to_i, Announcement.count, Article.all.map(&:slug).join(",") ].join("-")
    when "games" then [ Game.maximum(:updated_at)&.to_i, Game.count ].join("-")
    when "players" then [ Player.maximum(:updated_at)&.to_i, Player.count ].join("-")
    end
  end

  def lastmod_of(part)
    case part
    when "pages" then [ Season.maximum(:updated_at), Announcement.maximum(:updated_at) ].compact.max
    when "games" then Game.maximum(:updated_at)
    when "players" then Player.maximum(:updated_at)
    end
  end

  def pages_entries
    universities = University.order(:position).to_a

    entries = [
      Entry.new(loc: root_url, changefreq: "daily", priority: "1.0"),
      Entry.new(loc: seasons_url, changefreq: "weekly", priority: "0.8"),
      Entry.new(loc: card_orders_seasons_url, changefreq: "monthly", priority: "0.5"),
      Entry.new(loc: standings_orders_seasons_url, changefreq: "monthly", priority: "0.5"),
      Entry.new(loc: conventions_seasons_url, changefreq: "monthly", priority: "0.5"),
      Entry.new(loc: strength_seasons_url, changefreq: "monthly", priority: "0.4"),
      Entry.new(loc: matchups_url, changefreq: "weekly", priority: "0.8"),
      Entry.new(loc: games_url, changefreq: "daily", priority: "0.8"),
      Entry.new(loc: universities_url, changefreq: "weekly", priority: "0.6"),
      Entry.new(loc: players_url, changefreq: "weekly", priority: "0.5"),
      Entry.new(loc: rankings_url, changefreq: "weekly", priority: "0.5"),
      Entry.new(loc: ranking_url("pitching"), changefreq: "weekly", priority: "0.4"),
      Entry.new(loc: news_url, lastmod: Announcement.maximum(:updated_at), changefreq: "weekly", priority: "0.4"),
      Entry.new(loc: articles_url, changefreq: "monthly", priority: "0.4"),
      *Article.all.map { |article| Entry.new(loc: article_url(article.slug), lastmod: article.published_on, changefreq: "monthly", priority: "0.5") },
      Entry.new(loc: api_docs_url, changefreq: "monthly", priority: "0.3"),
      *DeveloperDoc.all.map { |doc| Entry.new(loc: "#{root_url.chomp("/")}#{doc.site_path}", lastmod: doc.updated_at, changefreq: "monthly", priority: "0.2") }
    ]

    Announcement.select(:id, :updated_at).find_each do |announcement|
      entries << Entry.new(loc: news_item_url(announcement), lastmod: announcement.updated_at, changefreq: "monthly", priority: "0.3")
    end

    universities.each do |u|
      entries << Entry.new(loc: university_url(u.slug), changefreq: "weekly", priority: "0.6")
    end

    Season.select(:id, :year, :term, :updated_at).order(:year, :term).each do |s|
      entries << Entry.new(loc: season_url(s.year, s.term), lastmod: s.updated_at, changefreq: "weekly", priority: "0.7")
    end

    universities.combination(2).each do |a, b|
      entries << Entry.new(loc: matchup_url(a.slug, b.slug), changefreq: "monthly", priority: "0.5")
    end

    entries
  end

  def games_entries
    # Not the cancelled games: they have no page (a cancelled game and its replay
    # share a round number, and so a URL).
    games = Game.held.includes(:team0, :team1).order(:played_on, :game_number).to_a
    LiteSeasonPreload.attach(games)

    games.map do |g|
      Entry.new(
        loc: matchup_game_url(g.team0.slug, g.team1.slug, g.season.year, g.season.term, g.game_number),
        lastmod: g.updated_at, changefreq: "monthly", priority: "0.4"
      )
    end
  end

  # Newest entrants first, the ones most searched for now; plucked, since a
  # Player per row would be thousands of objects for two columns.
  def players_entries
    Player.order(Arel.sql("enter_year DESC NULLS LAST"), :scorebook_id).pluck(:scorebook_id, :updated_at).map do |scorebook_id, updated_at|
      Entry.new(loc: player_url(scorebook_id), lastmod: updated_at, changefreq: "weekly", priority: "0.5")
    end
  end
end
