class IntegrationsController < AuthenticatedController
  before_action :set_provider, only: %i[test_connection]

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

    if params.dig(:business, :integration_adapter_mode).present?
      @business.update!(integration_adapter_mode: params[:business][:integration_adapter_mode])
    end

    ActiveRecord::Base.transaction do
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
    setting = Current.business.integration_settings.find_by(provider_key: provider)

    result = case provider
    when "payment_gateway"
      AdapterResolver.resolve(Current.business, :payment_gateway).test_connection(settings: setting_credentials(setting))
    when "maps"
      test_maps_connection(setting)
    when "fiscal"
      AdapterResolver.resolve(Current.business, :fiscal).test_connection(settings: setting_credentials(setting))
    when "marketplace"
      AdapterResolver.resolve(Current.business, :marketplace).test_connection(settings: setting_credentials(setting))
    when "messaging"
      AdapterResolver.resolve(Current.business, :messaging).test_connection(settings: setting_credentials(setting))
    else
      { success: false, message: t("integrations.providers.unknown") }
    end

    render json: result
  end

  private

  def set_provider
    @provider = params[:provider]
  end

  def load_settings
    IntegrationSetting::PROVIDER_KEYS.each_with_object({}) do |key, hash|
      setting = Current.business.integration_settings.find_by(provider_key: key)
      hash[key] = setting || IntegrationSetting.new(provider_key: key, enabled: true, credentials: {})
    end
  end

  def setting_credentials(setting)
    setting&.credentials&.deep_symbolize_keys || {}
  end

  def test_maps_connection(setting)
    creds = setting_credentials(setting)
    provider = creds[:provider].presence || "osm"

    case provider
    when "google"
      if creds[:api_key].present?
        MockMapsProvider.test_connection(settings: creds)
      else
        { success: false, message: "Chave da API do Google Maps não configurada" }
      end
    else
      OsmMapsProvider.test_connection(settings: creds.except(:provider, :api_key))
    end
  rescue => e
    { success: false, message: t("integrations.providers.error", error: e.message) }
  end
end
