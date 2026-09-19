class CreatePrimeMinisterTermsAndGdpPerCapitaYears < ActiveRecord::Migration[8.1]
  def change
    # One row per continuous term of a Prime Minister of Japan. start_on is
    # inclusive, end_on exclusive (the day a successor takes office belongs to
    # the successor); end_on is null for the incumbent.
    create_table :prime_minister_terms do |t|
      t.string :name, null: false
      t.date :start_on, null: false
      t.date :end_on
      t.timestamps
    end
    add_index :prime_minister_terms, :start_on

    # Japan's GDP per capita in current US$ (World Bank), one row per year.
    create_table :gdp_per_capita_years do |t|
      t.integer :year, null: false
      t.integer :usd, null: false
      t.timestamps
    end
    add_index :gdp_per_capita_years, :year, unique: true
  end
end
