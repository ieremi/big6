class TeamOgImage < OgImage
  def initialize(team, subtitle:)
    @team = team
    @subtitle = subtitle
  end

  def to_png
    bg = solid_background(@team.color)

    bg, = overlay_text(bg, @team.initial, dpi: 260, center_y: 190)
    bg, = overlay_text(bg, @team.slug.upcase, dpi: dpi_to_fit(@team.slug.upcase, 700, max_dpi: 150), center_y: 360)
    bg, = overlay_text(bg, @subtitle, dpi: 100, center_y: 440)
    bg, = overlay_text(bg, "Tokyo Big 6 Baseball", dpi: 90, center_y: 485)

    finalize(bg)
  end
end
