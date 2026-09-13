class SiteOgImage < OgImage
  TITLE_MAX_DPI = 260

  def initialize(title:, subtitle: nil, stripe_colors: nil)
    @title = title
    @subtitle = subtitle
    @stripe_colors = stripe_colors
  end

  def to_png
    colors = @stripe_colors || University.order(:position).map(&:color)
    bg = stripe_background(colors)
    bg = contrast_band(bg, center_y: 315, height: @subtitle.present? ? 260 : 180)

    title_dpi = dpi_to_fit(@title, 1000, max_dpi: TITLE_MAX_DPI)
    bg, = overlay_text(bg, @title, dpi: title_dpi, center_y: @subtitle.present? ? 260 : 300)
    bg, = overlay_text(bg, @subtitle, dpi: 110, center_y: 380) if @subtitle.present?
    bg, = overlay_text(bg, "Tokyo Big 6 Baseball", dpi: 90, center_y: @subtitle.present? ? 430 : 380)

    finalize(bg)
  end
end
