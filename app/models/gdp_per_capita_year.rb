# Japan's GDP per capita in current US$ for one calendar year. Populated by
# ReferenceDataSync (script/big6/update_reference_data.rb).
class GdpPerCapitaYear < ApplicationRecord
  # nil for years with no published figure (before 1960, or not out yet).
  def self.usd_for(year)
    where(year: year).pick(:usd)
  end
end
