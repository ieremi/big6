# Japan's GDP per capita in current US$, by calendar year, loaded from
# db/reference/gdp_per_capita.yml (regenerate with script/big6/update_reference_data.rb).
class GdpPerCapita
  DATA_PATH = Rails.root.join("db/reference/gdp_per_capita.yml")

  class << self
    # nil for years with no published figure (before 1960, or not out yet).
    def for_year(year)
      values[year]
    end

    private

    def values
      @values ||= YAML.safe_load_file(DATA_PATH)
    end
  end
end
