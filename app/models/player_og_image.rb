require "cgi"

# The OG image for a player page: the name large on the university's colour,
# with the university, entry year, and position beneath. Japanese text needs a
# CJK font on the machine (the Dockerfiles install one); libvips falls back to
# it for those glyphs.
class PlayerOgImage < OgImage
  NAME_TARGET_WIDTH = 1000
  NAME_MAX_DPI = 800
  DETAIL_TARGET_WIDTH = 900
  DETAIL_MAX_DPI = 300
  PROFILE_MAX_DPI = 240
  CREDIT_DPI = 110
  GAP = 40

  def initialize(player)
    @player = player
  end

  def to_png
    bg = solid_background(@player.university.color)

    lines = text_lines
    heights = lines.map { |text, dpi| text_height(text, dpi) }
    y = (HEIGHT - (heights.sum + GAP * (lines.size - 1))) / 2.0

    lines.zip(heights).each do |(text, dpi), height|
      bg, = overlay_text(bg, text, dpi: dpi, center_y: y + height / 2.0)
      y += height + GAP
    end

    finalize(bg)
  end

  private

  # [[text, dpi], ...] from top to bottom. libvips treats the text as Pango
  # markup, so each line is escaped before it is measured or drawn.
  def text_lines
    name = escape(@player.name.gsub(/[[:space:]]+/, " "))
    detail = escape([ @player.university.name, ("#{@player.enter_year}年入学" if @player.enter_year) ].compact.join("　"))
    profile = escape([ (@player.role unless @player.role == "選手"), @player.position, @player.hands_label.presence ].compact_blank.join("　"))

    lines = [
      [ name, dpi_to_fit(name, NAME_TARGET_WIDTH, max_dpi: NAME_MAX_DPI) ],
      [ detail, dpi_to_fit(detail, DETAIL_TARGET_WIDTH, max_dpi: DETAIL_MAX_DPI) ]
    ]
    lines << [ profile, dpi_to_fit(profile, DETAIL_TARGET_WIDTH, max_dpi: PROFILE_MAX_DPI) ] if profile.present?
    lines << [ "Tokyo Big 6 Baseball", CREDIT_DPI ]
  end

  def escape(text)
    CGI.escapeHTML(text)
  end
end
