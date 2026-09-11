class RenameRikkyoSlugToRikkio < ActiveRecord::Migration[8.1]
  def up
    execute "UPDATE universities SET slug = 'rikkio' WHERE slug = 'rikkyo'"
  end

  def down
    execute "UPDATE universities SET slug = 'rikkyo' WHERE slug = 'rikkio'"
  end
end
