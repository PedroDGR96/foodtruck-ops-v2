class IntegrationsController < AuthenticatedController
  def edit
    @business = Current.business
    authorize @business, :update?
    @providers = IntegrationSetting::PROVIDER_KEYS
    @active_tab = params[:tab] || @providers.first
    @settings = load_settings
  end

  def update
    @business = Current.business
    authorize @business, :update?

    ActiveRecord::Base.transaction do
      if params.dig(:business, :integration_adapter_mode).present?
        @business.update!(integration_adapter_mode: params[:business][:integration_adapter_mode])
      end

      (params.fetch(:integrations, {}) || {}).each do |provider_key, attrs|
        next if attrs.blank?

        credentials = attrs[:credentials]&.to_unsafe_h&.except("controller", "action") || {}
        enabled = attrs[:enabled] == "1"

        setting = @business.integration_settings.find_or_initialize_by(provider_key: provider_key)
        setting.update!(credentials: credentials, enabled: enabled)
      end
    end

    AuditLog.record!(
      action: "integrations_updated",
      resource: "business",
      resource_id: @business.id,
      actor: current_user,
      metadata: { providers: params.fetch(:integrations, {}).keys }
    )

    redirect_to edit_integrations_path, notice: t("integrations.updated")
  rescue ActiveRecord::RecordInvalid => e
    flash.now[:alert] = e.message
    @business ||= Current.business
    @providers = IntegrationSetting::PROVIDER_KEYS
    @active_tab = params[:tab] || @providers.first
    @settings = load_settings
    render :edit, status: :unprocessable_content
  end

  def test_connection
    @business = Current.business
    authorize @business, :update?

    provider = params[:provider]
    unless IntegrationSetting::PROVIDER_KEYS.include?(provider)
      return render json: { success: false, message: t("integrations.providers.unknown") }
    end

    setting = Current.business.integration_settings.find_by(provider_key: provider)
    adapter = AdapterResolver.resolve(Current.business, provider)

    render json: adapter.test_connection(settings: setting_credentials(setting))
  end

  private

  def load_settings
    IntegrationSetting::PROVIDER_KEYS.each_with_object({}) do |key, hash|
      setting = Current.business.integration_settings.find_by(provider_key: key)
      hash[key] = setting || IntegrationSetting.new(provider_key: key, enabled: true, credentials: {})
    end
  end

  def setting_credentials(setting)
    setting&.credentials&.deep_symbolize_keys || {}
  end
end
