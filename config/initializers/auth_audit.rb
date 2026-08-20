Warden::Manager.before_failure do |env, opts|
  request = ActionDispatch::Request.new(env)
  next unless request.post?

  attempted_path = opts[:attempted_path].to_s
  sign_in_path = "#{Devise.mappings[:user]&.fullpath || '/users'}/sign_in"
  next unless attempted_path == sign_in_path

  email = request.parameters.dig("user", "email")&.downcase
  user = email.presence && User.unscoped.find_by(email: email)
  next unless user

  Tenancy.with_business(user.business) do
    AuditLog.record!(
      action: "failed_sign_in",
      resource: "user",
      resource_id: user.id,
      actor_id: user.id,
      metadata: { ip: request.remote_ip }
    )
  end
end
