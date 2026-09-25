module NewsHelper
  # An http(s) URL in plain text: ASCII only, so a URL written in full-width
  # brackets ("（https://...）") ends where the bracket starts.
  URL_PATTERN = %r{https?://[A-Za-z0-9\-._~:/?#\[\]@!$&'*+,;=%]+}

  # A notice's text with its URLs as links (opening in a new tab) and its line
  # breaks kept; everything else is escaped, so the text is never read as HTML.
  def linked_text(text)
    safe_join(text.to_s.split("\n", -1).map { |line| linked_line(line) }, tag.br)
  end

  private

  def linked_line(line)
    parts = []
    rest = line.chomp("\r")
    while (match = URL_PATTERN.match(rest))
      parts << match.pre_match
      parts << link_to(match[0], match[0], target: "_blank", rel: "noopener noreferrer")
      rest = match.post_match
    end
    parts << rest
    safe_join(parts)
  end
end
