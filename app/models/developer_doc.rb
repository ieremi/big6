# A page of the developers' notes in docs/ (Markdown), shown on the site at
# /developers (docs/README.md) and /developers/<name> (docs/<name>.md). The
# Markdown in the repository is the one source: the site renders it as it is.
#
# Links between the pages (league-site-game-page.md) become the site's own
# URLs, and links to other files of the repository (../CLAUDE.md) point to
# them on GitHub, where the repository is public.
class DeveloperDoc
  DIR = Rails.root.join("docs")
  INDEX = "README".freeze
  REPOSITORY_URL = "https://github.com/ieremi/big6/blob/main/".freeze

  attr_reader :name

  # The page with that name ("index" or nil for the README), or nil when there
  # is none. Only plain names are looked up, so no path outside docs/ is read.
  def self.find(name)
    name = INDEX if name.blank? || name == "index"
    return nil unless name == INDEX || name.match?(/\A[a-z0-9][a-z0-9-]*\z/)

    path = DIR.join("#{name}.md")
    path.file? ? new(name, path) : nil
  end

  # Every page, the README first.
  def self.all
    names = DIR.glob("*.md").map { |path| path.basename(".md").to_s }
    (([ INDEX ] & names) + (names - [ INDEX ]).sort).filter_map { |name| find(name) }
  end

  def initialize(name, path)
    @name = name
    @path = path
  end

  def index?
    name == INDEX
  end

  # The URL path of the page on the site.
  def site_path
    index? ? "/developers" : "/developers/#{name}"
  end

  def markdown
    @markdown ||= @path.read
  end

  # The first heading.
  def title
    markdown[/^# (.+)$/, 1].to_s.strip
  end

  # The first paragraph, for the page's description.
  def summary
    markdown.split(/\n{2,}/).find { |block| !block.start_with?("#", "|", "-", "`", ">") }.to_s.gsub(/\s+/, " ").strip
  end

  def updated_at
    @path.mtime
  end

  # The page as HTML, its links pointed at the site or GitHub. Raw HTML in the
  # Markdown isn't let through.
  def html
    rendered = Commonmarker.to_html(markdown, options: { render: { unsafe: false }, extension: { table: true, autolink: true, strikethrough: true } })
    fragment = Nokogiri::HTML::DocumentFragment.parse(rendered)
    fragment.css("a[href]").each { |link| point(link) }
    fragment.to_html
  end

  private

  def point(link)
    href = link["href"]
    if href.match?(%r{\Ahttps?://})
      link["target"] = "_blank"
      link["rel"] = "noopener noreferrer"
    elsif (page = href[/\A([a-z0-9-]+|README)\.md(#.*)?\z/, 1])
      link["href"] = (page == INDEX ? "/developers" : "/developers/#{page}") + href[/#.*\z/].to_s
    elsif !href.start_with?("#", "/")
      link["href"] = REPOSITORY_URL + File.expand_path(href, "/docs").delete_prefix("/")
      link["target"] = "_blank"
      link["rel"] = "noopener noreferrer"
    end
  end
end
