module Admin
  # The fixes the nightly Scorebook check suggests (FixSuggestion), for an admin
  # to approve or discard, and to apply an approved one to our batting lines,
  # or to the winning and losing pitchers (or take it out again).
  class SuggestionsController < BaseController
    LIMIT = 200

    before_action :set_suggestion, only: %i[show update apply unapply]

    def index
      @status = FixSuggestion::STATUSES.include?(params[:status]) ? params[:status] : "pending"
      @counts = FixSuggestion.group(:status).count
      @suggestions = FixSuggestion.where(status: @status)
        .includes(:university, :lines, game: %i[team0 team1])
        .order(played_on: :desc, id: :desc).limit(LIMIT).to_a
      # The games Scorebook files the lines under, in one query rather than one per row.
      @filed_games = Game.where(scorebook_game_id: @suggestions.map(&:scorebook_game_id).compact)
        .includes(:team0, :team1).index_by(&:scorebook_game_id)
    end

    def show
      @lines = @suggestion.lines.includes(player: :university)
    end

    # Records a decision; from the list (a discarded one taken back) it returns
    # to the list it came from.
    def update
      previous = @suggestion.status
      @suggestion.decide!(params[:decision].to_s, user: current_user, note: params[:note])
      back = params[:return_to] == "list" ? admin_suggestions_path(status: previous) : admin_suggestions_path(status: "pending")
      redirect_to back, notice: "#{helpers.fix_suggestion_title(@suggestion)}を「#{helpers.fix_suggestion_status_label(@suggestion.status)}」にしました。"
    rescue ArgumentError
      redirect_to admin_suggestion_path(@suggestion), alert: "決定の種類がわかりません。"
    rescue FixSuggestion::NotAllowed => e
      redirect_to admin_suggestion_path(@suggestion), alert: e.message
    end

    # Applies the lines, and publishes (or updates) the notice with the title and
    # body from the form.
    def apply
      had_notice = @suggestion.announcement.present?
      changed = @suggestion.apply!(user: current_user, title: params[:announcement_title], body: params[:announcement_body])
      what = @suggestion.kind == "pitcher_decisions" ? "勝利投手・敗戦投手を直し（#{changed}人分）" : "#{changed}人分の打撃成績を反映し"
      redirect_to admin_suggestion_path(@suggestion), notice: "#{what}、おしらせを#{had_notice ? "更新" : "掲載"}しました。"
    rescue FixSuggestion::NotAllowed => e
      redirect_to admin_suggestion_path(@suggestion), alert: e.message
    end

    def unapply
      removed = @suggestion.unapply!
      what = @suggestion.kind == "pitcher_decisions" ? "Scorebook から取り込み直し、おしらせを削除" : "#{removed}人分の打撃成績とおしらせを削除"
      redirect_to admin_suggestion_path(@suggestion), notice: "反映を取り消しました（#{what}）。"
    rescue FixSuggestion::NotAllowed => e
      redirect_to admin_suggestion_path(@suggestion), alert: e.message
    end

    private

    def set_suggestion
      @suggestion = FixSuggestion.find(params[:id])
    end
  end
end
