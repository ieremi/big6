# Titles and descriptions of the public pages, written for search engines and
# AI search as much as for the browser tab: a title says what the page is in
# the words people search with (東京六大学野球, 成績, 順位表, 対戦成績), and a
# description gives the figures themselves, so a search result or an AI's
# answer can quote it without opening the page.
#
# Structured data (JSON-LD, schema.org) says the same in a form machines read
# without guessing: a game is a SportsEvent between two SportsTeams, a player a
# Person on one of them. Only what the page itself shows goes in, as Google
# asks; so there is no BreadcrumbList, as the pages show no breadcrumbs.
module SeoHelper
  LEAGUE = { "@type" => "SportsOrganization", "name" => "東京六大学野球連盟", "alternateName" => "東京六大学野球", "url" => "https://www.big6.gr.jp/" }.freeze
  SITE_SUFFIX = "東京六大学野球 - Big6".freeze

  # "2026年秋季 順位表 - 東京六大学野球 - Big6".
  def site_title(*parts)
    [ *parts.compact_blank, SITE_SUFFIX ].join(" - ")
  end

  # ".456", or "-" for none.
  def seo_rate(value)
    value.nil? ? "-" : format("%.3f", value).sub(/\A0/, "")
  end

  # Every university's place, 勝ち点 and record.
  # For a season taken from a club's history, from the printed table.
  def standings_meta_description(season, standings)
    if (table = season.source_standings)
      names = University.where(slug: table["rows"].map { |row| row["university"] }).index_by(&:slug)
      rows = table["rows"].map do |row|
        "#{names[row["university"]]&.short_name} #{row["wins"]}勝#{row["losses"]}敗#{"#{row["draws"]}分" if row["draws"].to_i.positive?}"
      end
      return "東京六大学野球 #{season.title}の勝敗表（#{table["citation"]}より）。#{rows.join("、")}"
    end
    return "東京六大学野球 #{season.title}の順位表。このサイトにある試合は一部で、出典に勝敗表がないため順位表は載せていない。" if season.from_printed_sources?

    table = standings.rows.map do |row|
      "#{row.rank}位 #{row.university.short_name}（勝ち点#{row.points}、#{row.wins}勝#{row.losses}敗#{"#{row.draws}分" if row.draws.positive?}）"
    end
    "東京六大学野球 #{season.title}の順位表。#{table.join('、')}"
  end

  def university_meta_description(university, record)
    "#{university.name}の東京六大学野球リーグ戦での通算成績（#{record.wins}勝#{record.losses}敗#{record.draws}分、勝率#{seo_rate(record.percentage)}）と、シーズンごとの成績・試合結果。"
  end

  # Wins of each side and draws in the games the page lists (the whole history,
  # a year or a season).
  def matchup_meta_description(team0, team1, games, period_label: nil)
    decided = games.select(&:decided?)
    wins = ->(team) { decided.count { |game| (game.team0_id == team.id ? game.team0_score - game.team1_score : game.team1_score - game.team0_score).positive? } }
    draws = decided.count { |game| game.team0_score == game.team1_score }
    record = "#{team0.short_name}#{wins.(team0)}勝、#{team1.short_name}#{wins.(team1)}勝、#{draws}分"
    "東京六大学野球 #{team0.short_name}と#{team1.short_name}の#{period_label || "通算"}の対戦成績（#{record}）と試合結果。"
  end

  # A <script type="application/ld+json"> with the objects, for the page's head
  # (content_for :head). json_escape keeps a name with "</script>" in it from
  # ending the tag.
  def structured_data(*objects)
    data = objects.compact.map { |object| { "@context" => "https://schema.org" }.merge(object) }
    tag.script(json_escape((data.one? ? data.first : data).to_json).html_safe, type: "application/ld+json") # rubocop:disable Rails/OutputSafety
  end

  def website_structured_data
    { "@type" => "WebSite", "name" => "Big6", "alternateName" => "東京六大学野球データベース", "url" => root_url, "inLanguage" => "ja",
      "description" => "東京六大学野球（1922年〜）の試合結果・順位表・対戦成績・選手成績のデータベース" }
  end

  def university_structured_data(university)
    { "@type" => "SportsTeam", "name" => university.name, "alternateName" => university.short_name, "sport" => "Baseball",
      "memberOf" => LEAGUE, "url" => university_url(university.slug) }
  end

  # The player and the university they play (or played) for. alumniOf is their
  # high school, as the page lists it; jobTitle a member of staff's role.
  def player_structured_data(player)
    {
      "@type" => "Person", "name" => player.name, "alternateName" => player.name_kana.presence, "url" => player_url(player),
      "memberOf" => university_structured_data(player.university).except("memberOf"),
      "alumniOf" => (player.high_school.present? ? { "@type" => "EducationalOrganization", "name" => player.high_school } : nil),
      "jobTitle" => (player.role if Player::STAFF_ROLES.include?(player.role)) # 監督, 部長: a student player has none
    }.compact
  end

  # A game: team0 is the visitor (batting first, as Scorebook records it), team1
  # the home side. A game not held is EventCancelled; the rest are as scheduled,
  # schema.org having no status for a game being or having been played.
  def game_structured_data(game, description:, stadium: nil)
    {
      "@type" => "SportsEvent", "name" => "#{game.team0.short_name} vs #{game.team1.short_name}（#{game.season.title}第#{game.game_number}回戦）",
      "description" => description, "sport" => "Baseball", "startDate" => game.played_on.iso8601, "url" => request.original_url.split("?").first,
      "eventStatus" => "https://schema.org/#{game.not_held? ? "EventCancelled" : "EventScheduled"}",
      "awayTeam" => university_structured_data(game.team0).except("memberOf"),
      "homeTeam" => university_structured_data(game.team1).except("memberOf"),
      "location" => (stadium.present? ? { "@type" => "Place", "name" => stadium.to_s.strip } : nil),
      "organizer" => LEAGUE
    }.compact
  end
end
