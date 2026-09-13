class UniversityStatsOgImage < OgImage
  NAME_TARGET_WIDTH = 700
  NAME_MAX_DPI = 320
  TEXT_TARGET_WIDTH = 1080
  MAX_DPI = 220
  GAP = 24

  def initialize(university, streak_length:, rate:, subtitle:)
    @university = university
    @streak_length = streak_length
    @rate = rate
    @subtitle = subtitle
  end

  def to_png
    bg = solid_background(@university.color)

    name_line = @university.slug.capitalize
    streak_line = @streak_length ? "the Best: #{@streak_length} victories in a row" : "No winning streak yet"
    rate_line = "winning rate: #{format_rate(@rate)}"

    name_dpi = dpi_to_fit(name_line, NAME_TARGET_WIDTH, max_dpi: NAME_MAX_DPI)
    primary_dpi = dpi_to_fit([ streak_line, rate_line ].max_by(&:length), TEXT_TARGET_WIDTH, max_dpi: MAX_DPI)
    secondary_dpi = (primary_dpi * 0.55).round

    name_h = text_height(name_line, name_dpi)
    streak_h = text_height(streak_line, primary_dpi)
    rate_h = text_height(rate_line, primary_dpi)
    subtitle_h = text_height(@subtitle, secondary_dpi)
    credit_h = text_height("Tokyo Big 6 Baseball", secondary_dpi)

    total_height = name_h + GAP * 2 + streak_h + GAP + rate_h + GAP * 2 + subtitle_h + GAP + credit_h
    top = (HEIGHT - total_height) / 2.0

    name_center_y = top + name_h / 2.0
    streak_center_y = top + name_h + GAP * 2 + streak_h / 2.0
    rate_center_y = top + name_h + GAP * 2 + streak_h + GAP + rate_h / 2.0
    subtitle_center_y = top + name_h + GAP * 2 + streak_h + GAP + rate_h + GAP * 2 + subtitle_h / 2.0
    credit_center_y = top + name_h + GAP * 2 + streak_h + GAP + rate_h + GAP * 2 + subtitle_h + GAP + credit_h / 2.0

    bg, = overlay_text(bg, name_line, dpi: name_dpi, center_y: name_center_y)
    bg, = overlay_text(bg, streak_line, dpi: primary_dpi, center_y: streak_center_y)
    bg, = overlay_text(bg, rate_line, dpi: primary_dpi, center_y: rate_center_y)
    bg, = overlay_text(bg, @subtitle, dpi: secondary_dpi, center_y: subtitle_center_y)
    bg, = overlay_text(bg, "Tokyo Big 6 Baseball", dpi: secondary_dpi, center_y: credit_center_y)

    finalize(bg)
  end

  private

  def format_rate(value)
    return "—" if value.nil?

    format("%.3f", value).sub(/\A0/, "")
  end
end
