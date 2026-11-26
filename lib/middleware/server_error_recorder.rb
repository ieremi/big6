# Records each request that ends in a 500 as a ServerError, for the admin
# pages, and lets the exception go on to Rails's error page as before. It sits
# just inside ActionDispatch::DebugExceptions (config/application.rb), so it
# sees what the app raised before the exception is turned into a response.
# Exceptions Rails answers with a 4xx (a record not found, a bad parameter) are
# not errors of the site and are left out.
#
# Recording must never be what fails the request, so any error while
# recording (the database being the trouble, say) is only logged.
class ServerErrorRecorder
  def initialize(app)
    @app = app
  end

  def call(env)
    @app.call(env)
  rescue Exception => exception # rubocop:disable Lint/RescueException
    record(exception, env)
    raise
  end

  private

  def record(exception, env)
    return if ActionDispatch::ExceptionWrapper.status_code_for_exception(exception.class.name) < 500

    ServerError.record(exception, ActionDispatch::Request.new(env))
  rescue StandardError => error
    Rails.logger.error("ServerErrorRecorder could not record #{exception.class}: #{error.class}: #{error.message}")
  end
end
