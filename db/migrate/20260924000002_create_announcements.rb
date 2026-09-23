class CreateAnnouncements < ActiveRecord::Migration[8.1]
  def change
    # A notice to the site's visitors, shown on the home page (the latest few)
    # and at /news. For now each comes from applying a FixSuggestion (one per
    # suggestion, updated when more of its lines are applied, deleted when
    # the application is taken back); fix_suggestion is empty for any other.
    create_table :announcements do |t|
      t.string :title, null: false
      t.text :body, null: false
      t.datetime :published_at, null: false
      t.references :fix_suggestion, foreign_key: true, index: { unique: true }
      t.timestamps
    end
    add_index :announcements, :published_at
  end
end
