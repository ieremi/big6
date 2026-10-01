# The MCP server (Model Context Protocol) at /mcp, through which AI assistants
# call the Web API as tools: ChatGPT, whose GPTs (and their OpenAPI Actions) are
# retired on 2026-12-11 in favour of plugins built on MCP apps, and Claude and
# the like too.
#
# The tools aren't written out here: there is one for each operation of the
# API's OpenAPI description (config/openapi.yml, Api::V1::OpenapiController),
# named after its operationId ("search_players" for searchPlayers), taking its
# parameters, and answering with the API's own JSON. A tool call is a GET on
# the API inside this app (Rails.application.call), so the tools, the API and
# its two descriptions can't drift apart, and there is no second copy of how
# a game or a player is put into JSON.
#
# Read-only and without sign-in, like the API. Each request gets a server and a
# transport of its own, stateless and answering in plain JSON rather than an
# SSE stream: nothing is kept between requests, which suits Puma's threads and
# a single small instance.
class Big6Mcp
  NAME = "big6"
  TITLE = "Big6 東京六大学野球"

  INSTRUCTIONS = <<~TEXT.freeze
    東京六大学野球（1925年〜）の試合・シーズン・順位表・対戦成績・選手と成績・ランキングを調べるツールです。すべて読み取り専用です。
    大学は slug で指定します: waseda（早大）、keio（慶大）、meiji（明大）、hosei（法大）、tokyo（東大）、rikkio（立大）。
    シーズンは year（年）と term（spring＝春季、autumn＝秋季）です。
    選手は id（BIG6 Scorebook の選手ID）で指定します。名前しかわからないときは、まず search_players で id を調べてください。
    ある日の試合は get_season でシーズンの全試合を取り、played_on で絞ります。
  TEXT

  ANNOTATIONS = { read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false }.freeze

  # Rack interface, for mounting at /mcp (config/routes.rb).
  def self.call(env)
    request = Rack::Request.new(env)
    server = MCP::Server.new(
      name: NAME, title: TITLE, version: "1", website_url: request.base_url, instructions: INSTRUCTIONS,
      tools: tools, server_context: { base_url: request.base_url }
    )
    transport = MCP::Server::Transports::StreamableHTTPTransport.new(
      server,
      stateless: true, enable_json_response: true, serve_subscriptions_listen: false,
      # The protection is for servers bound to a local port that a web page could
      # reach by a rebound host name; this one is public, at any host Render gives it.
      dns_rebinding_protection: false
    )
    transport.handle_request(request)
  end

  # The tools, one for each operation of the OpenAPI description; built once.
  def self.tools
    @tools ||= spec.fetch("paths").flat_map do |path, item|
      item.map { |_verb, operation| tool_for(path, operation) }
    end.freeze
  end

  def self.spec
    Api::V1::OpenapiController.spec
  end

  def self.tool_for(path, operation)
    parameters = Array(operation["parameters"]).map { |parameter| resolve(parameter) }

    MCP::Tool.define(
      name: operation.fetch("operationId").underscore,
      title: operation["summary"],
      description: [ operation["summary"], operation["description"] ].compact.join("。"),
      input_schema: input_schema(parameters),
      annotations: ANNOTATIONS.merge(title: operation["summary"])
    ) do |server_context:, **arguments|
      Big6Mcp.call_api(path, parameters, arguments, base_url: server_context[:base_url])
    end
  end

  # The tool's arguments as a JSON Schema object: one property for each
  # parameter, under its name without the "[]" of an array in a query string.
  def self.input_schema(parameters)
    properties = parameters.to_h do |parameter|
      schema = resolve_all(parameter.fetch("schema"))
      schema = schema.merge("description" => parameter["description"]) if parameter["description"]
      [ argument_name(parameter), schema ]
    end
    required = parameters.select { |parameter| parameter["required"] }.map { |parameter| argument_name(parameter) }

    { properties: properties, required: required.presence }.compact
  end

  def self.argument_name(parameter)
    parameter.fetch("name").delete_suffix("[]")
  end

  # GETs the operation's path, with the arguments in it and in its query string,
  # from the API inside this app, and answers with the JSON it gives (as an error
  # for a 404 and the like).
  def self.call_api(path, parameters, arguments, base_url:)
    arguments = arguments.transform_keys(&:to_s)
    query = {}

    filled_path = path.gsub(/\{(\w+)\}/) { ERB::Util.url_encode(arguments.fetch($1).to_s) }
    parameters.select { |parameter| parameter["in"] == "query" }.each do |parameter|
      value = arguments[argument_name(parameter)]
      query[parameter.fetch("name")] = value unless value.nil?
    end

    url = URI("#{base_url}/api/v1#{filled_path}")
    url.query = query.to_query if query.any?
    # The Host header as the MCP request had it, which host authorization
    # (config.hosts) checks; env_for sets none of its own.
    env = Rack::MockRequest.env_for(url.to_s, "HTTP_HOST" => url.port == url.default_port ? url.host : "#{url.host}:#{url.port}", "HTTP_ACCEPT" => "application/json")
    status, _headers, body = Rails.application.call(env)
    json = +""
    body.each { |chunk| json << chunk }
    body.close if body.respond_to?(:close)

    parsed = JSON.parse(json) rescue nil
    MCP::Tool::Response.new([ { type: "text", text: json } ], error: status >= 400, structured_content: (parsed if parsed.is_a?(Hash)))
  end

  # Follows a "#/components/..." reference of the OpenAPI description.
  def self.resolve(node)
    return node unless node.is_a?(Hash) && node["$ref"]

    resolve(node["$ref"].delete_prefix("#/").split("/").reduce(spec) { |hash, key| hash.fetch(key) })
  end

  # A schema with every reference in it replaced by what it points at, since a
  # tool's input schema stands alone.
  def self.resolve_all(node)
    case node
    when Hash then resolve(node).transform_values { |value| resolve_all(value) }
    when Array then node.map { |value| resolve_all(value) }
    else node
    end
  end
end
