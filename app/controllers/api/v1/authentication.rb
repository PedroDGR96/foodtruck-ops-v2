module Api
  module V1
    # Bearer-token authentication. The token is resolved before any tenant
    # context exists (Token rows are not RLS-enforced), then the whole request
    # runs inside the token's business so every tenant-scoped query is guarded
    # by row-level security and the BusinessScoped default scope.
    module Authentication
      extend ActiveSupport::Concern

      included do
        around_action :authenticate_request
      end

      private

      attr_reader :current_user, :api_token

      def authenticate_request(options = {})
        token = Token.authenticate(bearer_token)
        raise Unauthorized if token.nil? || !token.active? || token.expired?

        Tenancy.with_business(token.business) do
          @api_token = token
          token.touch_last_used!
          @current_user = token.user
          yield
        end
      end

      def bearer_token
        request.headers["Authorization"].to_s.sub(/\ABearer /, "").presence
      end

      def require_writer!
        raise Forbidden, "Write access required" unless api_token.scope.in?(%w[writer admin])
      end
    end
  end
end
