module Users
  class SessionsController < Devise::SessionsController
    def new
      self.resource = resource_class.unscoped.new(sign_in_params)
      clean_up_passwords(resource)
      yield resource if block_given?
      respond_with(resource, serialize_options(resource))
    end

    def create
      business = candidate_business
      if business
        Tenancy.with_business(business) { authenticate! }
      else
        authenticate!
      end
    end

    def destroy
      user = current_user
      sign_out(current_user)
      AuditLog.record!(action: "sign_out", resource: "session", actor: user) if user
      redirect_to new_user_session_path, notice: t("devise.sessions.signed_out")
    end

    private

    def candidate_business
      email = params.dig(:user, :email)&.downcase
      user = email.presence && User.unscoped.find_by(email: email)
      user&.business
    end

    def authenticate!
      self.resource = warden.authenticate!(auth_options)

      if resource
        AuditLog.record!(action: "sign_in", resource: "session", actor: resource, metadata: { ip: request.remote_ip })
        set_flash_message!(:notice, :signed_in) if is_flashing_format?
        sign_in(resource_name, resource)
        yield resource if block_given?
        respond_with resource, location: after_sign_in_path_for(resource)
      end
    end
  end
end
