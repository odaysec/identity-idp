# frozen_string_literal: true

module DocAuth
  module Passports
    class HealthCheckResponseOk < DocAuth::Response
      def initialize(faraday_response)
        extra =
          if faraday_response.body && !faraday_response.body.empty?
            { body: faraday_response.body }
          else
            {}
          end

        super(
          success: faraday_response.success?,
          extra:
        )
      end
    end
  end
end
