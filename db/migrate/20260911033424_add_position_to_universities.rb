class AddPositionToUniversities < ActiveRecord::Migration[8.1]
  JOIN_ORDER = %w[keio meiji waseda hosei rikkyo tokyo]

  def up
    add_column :universities, :position, :integer

    JOIN_ORDER.each_with_index do |slug, index|
      execute <<~SQL
        UPDATE universities SET position = #{index + 1} WHERE slug = #{quote(slug)}
      SQL
    end

    change_column_null :universities, :position, false
    add_index :universities, :position, unique: true
  end

  def down
    remove_column :universities, :position
  end
end
