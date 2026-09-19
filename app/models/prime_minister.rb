# Prime Ministers of Japan, loaded from db/reference/prime_ministers.yml
# (regenerate with script/big6/update_reference_data.rb).
class PrimeMinister
  Term = Struct.new(:name, :start_on, :end_on, keyword_init: true)

  DATA_PATH = Rails.root.join("db/reference/prime_ministers.yml")

  class << self
    # Terms overlapping from..to, oldest first. A term runs from start_on up to
    # but not including end_on, so on the day a successor takes office only
    # the successor counts.
    def serving_between(from, to)
      return [] unless from && to

      terms.select { |term| term.start_on <= to && (term.end_on.nil? || term.end_on > from) }
    end

    private

    def terms
      @terms ||= YAML.safe_load_file(DATA_PATH, permitted_classes: [ Date ], symbolize_names: true).map { |attrs| Term.new(**attrs) }
    end
  end
end
