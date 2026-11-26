require "digest"

# A kind of error that turned a request into a 500, counted, for the admin
# pages (/admin/server_errors). Production has no error tracker and its logs
# can only be read in Render's dashboard, so the 500s in Render's metrics had
# no cause attached; ServerErrorRecorder (the middleware) records them here.
#
# Requests failing the same way share a row (the fingerprint: the exception
# class, the controller action and the first line of the app's own code in the
# backtrace), whose count goes up, so a burst of thousands stays one row. The
# message, path, user agent and backtrace are the latest request's.
class ServerError < ApplicationRecord
  BACKTRACE_LINES = 30

  scope :recent_first, -> { order(last_seen_at: :desc) }

  # Records exception, raised while serving request (an ActionDispatch::Request),
  # in one statement: a new row, or one more on the row of its kind.
  def self.record(exception, request, at: Time.current)
    parameters = request.path_parameters
    controller_action = ("#{parameters[:controller]}##{parameters[:action]}" if parameters[:controller])
    backtrace = Rails.backtrace_cleaner.clean(Array(exception.backtrace)).presence || Array(exception.backtrace)
    fingerprint = Digest::SHA256.hexdigest([ exception.class.name, controller_action, backtrace.first ].join("\n"))

    upsert(
      {
        fingerprint: fingerprint,
        exception_class: exception.class.name,
        message: exception.message.to_s.truncate(2_000),
        controller_action: controller_action,
        request_method: request.request_method,
        path: request.fullpath.to_s.truncate(2_000),
        user_agent: request.user_agent.to_s.truncate(500).presence,
        backtrace: backtrace.first(BACKTRACE_LINES).join("\n"),
        occurrences: 1,
        first_seen_at: at,
        last_seen_at: at
      },
      unique_by: :fingerprint,
      on_duplicate: Arel.sql(<<~SQL.squish)
        occurrences = server_errors.occurrences + 1,
        message = EXCLUDED.message,
        request_method = EXCLUDED.request_method,
        path = EXCLUDED.path,
        user_agent = EXCLUDED.user_agent,
        backtrace = EXCLUDED.backtrace,
        last_seen_at = EXCLUDED.last_seen_at
      SQL
    )
  end
end
