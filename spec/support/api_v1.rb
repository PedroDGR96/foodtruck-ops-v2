module ApiV1TestSupport
  def api_token_for(user, scope: "writer")
    _token, raw = Tenancy.with_business(user.business) do
      Token.issue!(user: user, scope: scope, name: "spec token")
    end
    raw
  end
end

RSpec.configure do |config|
  config.include ApiV1TestSupport, type: :request
end
