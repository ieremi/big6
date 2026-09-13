class IcsCalendar
  FOLD_LIMIT = 75
  TZID = "Asia/Tokyo"

  def initialize(name:)
    @name = name
    @events = []
  end

  def add_event(uid:, summary:, start_time: nil, end_time: nil, all_day_date: nil, location: nil, description: nil)
    @events << {
      uid: uid, summary: summary, start_time: start_time, end_time: end_time,
      all_day_date: all_day_date, location: location, description: description
    }
  end

  def to_ics
    lines = [
      "BEGIN:VCALENDAR",
      "VERSION:2.0",
      "PRODID:-//Big6//Big6 Baseball//EN",
      "CALSCALE:GREGORIAN",
      "X-WR-CALNAME:#{escape(@name)}",
      "X-WR-TIMEZONE:#{TZID}"
    ]

    lines.concat(timezone_lines) if @events.any? { |event| event[:start_time] }
    @events.each { |event| lines.concat(event_lines(event)) }

    lines << "END:VCALENDAR"
    lines.flat_map { |line| fold(line) }.join("\r\n") + "\r\n"
  end

  private

  # Japan has no DST, so a single fixed +09:00 offset covers all dates.
  def timezone_lines
    [
      "BEGIN:VTIMEZONE",
      "TZID:#{TZID}",
      "BEGIN:STANDARD",
      "DTSTART:19700101T000000",
      "TZOFFSETFROM:+0900",
      "TZOFFSETTO:+0900",
      "TZNAME:JST",
      "END:STANDARD",
      "END:VTIMEZONE"
    ]
  end

  def event_lines(event)
    lines = [
      "BEGIN:VEVENT",
      "UID:#{event[:uid]}",
      "DTSTAMP:#{Time.current.utc.strftime('%Y%m%dT%H%M%SZ')}"
    ]

    if event[:all_day_date]
      lines << "DTSTART;VALUE=DATE:#{event[:all_day_date].strftime('%Y%m%d')}"
      lines << "DTEND;VALUE=DATE:#{(event[:all_day_date] + 1).strftime('%Y%m%d')}"
    else
      lines << "DTSTART;TZID=#{TZID}:#{format_local(event[:start_time])}"
      lines << "DTEND;TZID=#{TZID}:#{format_local(event[:end_time])}" if event[:end_time]
    end

    lines << "SUMMARY:#{escape(event[:summary])}"
    lines << "LOCATION:#{escape(event[:location])}" if event[:location].present?
    lines << "DESCRIPTION:#{escape(event[:description])}" if event[:description].present?
    lines << "END:VEVENT"
    lines
  end

  def format_local(time)
    time.in_time_zone(TZID).strftime("%Y%m%dT%H%M%S")
  end

  def escape(text)
    text.to_s.gsub("\\", "\\\\\\\\").gsub(",", "\\,").gsub(";", "\\;").gsub("\n", "\\n")
  end

  # RFC 5545 line folding, done per-character so multi-byte UTF-8 text is
  # never split in the middle of a character.
  def fold(line)
    chunks = []
    current = +""
    current_bytesize = 0

    line.each_char do |char|
      if current_bytesize + char.bytesize > FOLD_LIMIT
        chunks << current
        current = +" "
        current_bytesize = 1
      end

      current << char
      current_bytesize += char.bytesize
    end

    chunks << current
    chunks
  end
end
