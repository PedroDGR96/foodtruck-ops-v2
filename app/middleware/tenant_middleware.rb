class TenantMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    business = Current.business
    return @app.call(env) unless business

    Tenancy.with_business(business) { @app.call(env) }
  ensure
    Current.reset
  end
end
