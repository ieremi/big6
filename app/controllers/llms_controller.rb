# /llms.txt: the site described for AI assistants and crawlers, in the format
# proposed at https://llmstxt.org (Markdown: the name, a summary, then sections
# of links with a note each). It says what the data is and where it comes from,
# how the pages and their URLs are laid out, and that the same data can be
# fetched as JSON (the Web API), described in OpenAPI, or called as tools (the
# MCP server), which an assistant can use instead of reading the pages.
#
# Rendered rather than a file in public/, so the links are absolute for
# whatever host serves it and the notes for developers listed are those there
# are.
class LlmsController < ApplicationController
  def show
    @docs = DeveloperDoc.all
    render layout: false, content_type: "text/plain", formats: :text
  end
end
