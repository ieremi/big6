class CreateServerErrors < ActiveRecord::Migration[8.1]
  def change
    # The requests that ended in a 500, recorded by ServerErrorRecorder for the
    # admin pages, since production has no error tracker. One row per kind of
    # error (the fingerprint: exception class, controller action and where in
    # the app it was raised), counted, rather than a row per request: a bad day
    # can bring tens of thousands. The request details are the latest one's.
    create_table :server_errors do |t|
      t.string :fingerprint, null: false
      t.string :exception_class, null: false
      t.text :message
      t.string :controller_action
      t.string :request_method
      t.text :path
      t.text :user_agent
      t.text :backtrace
      t.integer :occurrences, null: false, default: 1
      t.datetime :first_seen_at, null: false
      t.datetime :last_seen_at, null: false
    end
    add_index :server_errors, :fingerprint, unique: true
    add_index :server_errors, :last_seen_at
  end
end
