class TenantMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    business = Current.business || signed_in_business(env)
    return @app.call(env) unless business

    Tenancy.with_business(business) { @app.call(env) }
  ensure
    Current.reset
  end

  private

  def signed_in_business(env)
    user = env["warden"]&.user
    user&.business
  end
end
