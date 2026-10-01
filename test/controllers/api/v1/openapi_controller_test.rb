require "test_helper"

class Api::V1::OpenapiControllerTest < ActionDispatch::IntegrationTest
  def spec
    Api::V1::OpenapiController.spec
  end

  # Follows a "#/components/..." reference.
  def resolve(node)
    return node unless node.is_a?(Hash) && node["$ref"]

    node["$ref"].delete_prefix("#/").split("/").reduce(spec) { |hash, key| hash.fetch(key) }
  end

  def operations
    spec["paths"].flat_map { |path, item| item.map { |verb, operation| [ path, verb, operation ] } }
  end

  test "serves the description as JSON, with this site's API as its server" do
    get api_v1_openapi_url

    assert_response :success
    assert_equal "application/json", response.media_type
    body = response.parsed_body
    assert_equal "3.0.3", body["openapi"]
    assert_equal [ "http://www.example.com/api/v1" ], body["servers"].map { |server| server["url"] }
  end

  test "describes every JSON route of the API, and no route that isn't there" do
    routes = Rails.application.routes.routes.filter_map do |route|
      path = route.path.spec.to_s.delete_suffix("(.:format)")
      next unless route.verb == "GET" && path.start_with?("/api/v1/")
      next if path.end_with?("/og.png") || path == "/api/v1/openapi"

      path.delete_prefix("/api/v1").gsub(/:(\w+)/, '{\1}')
    end

    assert_equal routes.sort, spec["paths"].keys.sort
  end

  test "gives every operation a unique id and a description GPT Actions accept, and every path parameter a definition" do
    assert_equal operations.size, operations.map { |_, _, operation| operation["operationId"] }.uniq.size

    operations.each do |path, verb, operation|
      assert_equal "get", verb, path
      assert operation["description"].to_s.size <= 300, "#{path}: description longer than 300 characters"

      defined = Array(operation["parameters"]).map { |parameter| resolve(parameter) }.select { |parameter| parameter["in"] == "path" }.map { |parameter| parameter["name"] }
      assert_equal path.scan(/\{(\w+)\}/).flatten.sort, defined.sort, path
    end
  end

  test "every reference points at a component" do
    references = []
    walk = ->(node) do
      case node
      when Hash then node.each { |key, value| key == "$ref" ? references << value : walk.(value) }
      when Array then node.each(&walk)
      end
    end
    walk.(spec)

    assert references.any?
    references.uniq.each { |reference| assert resolve("$ref" => reference), reference }
  end
end
