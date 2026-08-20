require "rails_helper"

RSpec.configure do |config|
  config.swagger_root = Rails.root.join("swagger").to_s

  config.swagger_docs = {
    "v1/swagger.json" => {
      openapi: "3.0.1",
      info: {
        title: "FoodTruck Ops API v1",
        version: "v1"
      },
      paths: {},
      consumes: [ "application/json" ],
      produces: [ "application/json" ],
      components: {
        securitySchemes: {
          bearerAuth: {
            type: :http,
            scheme: :bearer,
            bearerFormat: "JWT"
          }
        }
      },
      security: [
        {
          bearerAuth: []
        }
      ]
    }
  }

  config.swagger_format = :json
  config.swagger_dry_run = true
end
