class GameScoreboard
  # Shared with the import scripts, which parse this once at import time
  # into Game#duration_minutes — this live parse is now only a fallback for
  # a game that hasn't been (re-)imported since that column was added.
  def self.parse_duration_minutes(text)
    match = text.to_s.match(/(?:(\d+)時間)?(?:(\d+)分)?/)
    return nil unless match && (match[1] || match[2])

    match[1].to_i * 60 + match[2].to_i
  end

  def initialize(game)
    @game = game
    @detail = game.season.scorebook_game(game.scorebook_game_id) || {}
  end

  def present?
    @detail.present?
  end

  def innings
    (1..18).select { |n| @detail["runs#{n}Top"].present? || @detail["runs#{n}Bottom"].present? }
  end

  def top_runs(inning)
    @detail["runs#{inning}Top"]
  end

  def bottom_runs(inning)
    @detail["runs#{inning}Bottom"]
  end

  def top_hits
    @detail["hitsTotalTop"]
  end

  def bottom_hits
    @detail["hitsTotalBottom"]
  end

  def top_errors
    @detail["errorsTotalTop"]
  end

  def bottom_errors
    @detail["errorsTotalBottom"]
  end

  def stadium
    @detail["stadium"]
  end

  def attendance
    @detail["attendance"]
  end

  def started_at
    @detail["gameStartActual"]
  end

  def finished_at
    @detail["gameFinishTime"]
  end

  def duration
    @detail["gameTimeNet"]
  end

  def duration_minutes
    @game.duration_minutes || self.class.parse_duration_minutes(duration)
  end

  def umpires
    [
      @detail["umpirePlate"], @detail["umpire1b"], @detail["umpire2b"],
      @detail["umpire3b"], @detail["umpireLeft"], @detail["umpireRight"]
    ].compact
  end

  def youtube_url
    return nil if @detail["youtubeId"].blank?

    "https://www.youtube.com/watch?v=#{@detail["youtubeId"]}"
  end
end
