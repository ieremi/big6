# A continuous term of a Prime Minister of Japan. Populated by
# ReferenceDataSync (script/big6/update_reference_data.rb).
class PrimeMinisterTerm < ApplicationRecord
  # Terms overlapping from..to, oldest first. A term runs from start_on up to
  # but not including end_on, so on the day a successor takes office only the
  # successor counts.
  def self.serving_between(from, to)
    return none unless from && to

    where(start_on: ..to).where("end_on IS NULL OR end_on > ?", from).order(:start_on)
  end
end
