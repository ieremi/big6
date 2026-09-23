module Admin
  # The fixes the nightly Scorebook check suggests (FixSuggestion), for an admin
  # to approve or discard. Deciding only records the decision for now.
  class SuggestionsController < BaseController
    LIMIT = 200

    before_action :set_suggestion, only: %i[show update]

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

    def update
      @suggestion.decide!(params[:decision].to_s, user: current_user, note: params[:note])
      redirect_to admin_suggestions_path(status: "pending"), notice: "#{helpers.fix_suggestion_title(@suggestion)}を「#{helpers.fix_suggestion_status_label(@suggestion.status)}」にしました。"
    rescue ArgumentError
      redirect_to admin_suggestion_path(@suggestion), alert: "決定の種類がわかりません。"
    end

    private

    def set_suggestion
      @suggestion = FixSuggestion.find(params[:id])
    end
  end
end
