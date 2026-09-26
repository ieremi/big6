module Admin
  # The findings of the games data check (GameDataCheck), by kind, for an
  # admin to look at: those marked fine (GameCheckReview) are left out unless
  # asked for. Nothing here changes the games.
  class GameChecksController < BaseController
    def index
      @show_reviewed = params[:reviewed].present?
      @reviews = GameCheckReview.includes(:reviewed_by).index_by(&:key)
      findings = GameDataCheck.new.findings
      @counts = findings.group_by(&:kind).transform_values { |list| [ list.size, list.count { |finding| @reviews.key?(finding.key) } ] }
      @findings_by_kind = findings.reject { |finding| !@show_reviewed && @reviews.key?(finding.key) }.group_by(&:kind)
    end

    # Marks a finding fine, with a note, or takes that back (remove=1).
    def review
      if params[:remove].present?
        GameCheckReview.where(key: params[:key]).destroy_all
        notice = "確認済みを取り消しました。"
      else
        review = GameCheckReview.find_or_initialize_by(key: params[:key])
        review.update!(note: params[:note].presence, reviewed_by: current_user)
        notice = "確認済み（正常）にしました。"
      end
      redirect_to admin_game_checks_path(reviewed: params[:reviewed].presence, anchor: params[:kind]), notice: notice
    end
  end
end
