class CreateUsersAndIdentities < ActiveRecord::Migration[8.1]
  def change
    # Someone who can sign in. For now only the admins (ADMIN_EMAILS) can
    # (LoginPolicy); admin marks them, as signing in may one day be open to
    # everyone.
    create_table :users do |t|
      t.string :email, null: false
      t.string :name
      t.boolean :admin, null: false, default: false
      t.datetime :last_signed_in_at
      t.timestamps
    end
    add_index :users, :email, unique: true

    # A way a user signs in: a provider (google_oauth2, ...) and the user's id
    # there. Kept apart from users so one user can have several.
    create_table :identities do |t|
      t.references :user, null: false, foreign_key: true
      t.string :provider, null: false
      t.string :uid, null: false
      t.string :email
      t.timestamps
    end
    add_index :identities, [ :provider, :uid ], unique: true
  end
end
