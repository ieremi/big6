module Admin
  # The errors that turned requests into 500s (ServerError, recorded by
  # ServerErrorRecorder), latest first, each with its count and the latest
  # request's details and backtrace. An admin deletes a row once it is fixed,
  # so it shows again only if the error comes back.
  class ServerErrorsController < BaseController
    LIMIT = 200

    def index
      @server_errors = ServerError.recent_first.limit(LIMIT)
      @total = ServerError.count
    end

    def show
      @server_error = ServerError.find(params[:id])
    end

    def destroy
      ServerError.find(params[:id]).destroy!
      redirect_to admin_server_errors_path, notice: "削除しました。"
    end

    def destroy_all
      ServerError.delete_all
      redirect_to admin_server_errors_path, notice: "すべて削除しました。"
    end
  end
end
