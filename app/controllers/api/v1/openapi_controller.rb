module Api
  module V1
    # The OpenAPI description of this API (config/openapi.yml), as JSON, for
    # tools that call an API only through one: a ChatGPT GPT's Actions import
    # it by URL. servers is this site's own /api/v1, so the same file serves
    # production and development alike.
    class OpenapiController < BaseController
      SPEC_PATH = Rails.root.join("config/openapi.yml")

      def show
        render json: self.class.spec.merge("servers" => [ { "url" => "#{request.base_url}/api/v1" } ])
      end

      def self.spec
        @spec ||= YAML.safe_load_file(SPEC_PATH).freeze
      end
    end
  end
end
