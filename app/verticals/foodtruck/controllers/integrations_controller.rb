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

    ActiveRecord::Base.transaction do
      params[:integrations].each do |provider_key, attrs|
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
      metadata: { providers: params[:integrations].keys }
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
    when "maps"
               test_maps_connection(setting)
    when "fiscal"
               MockFiscalProvider.test_connection(settings: setting_credentials(setting))
    when "marketplace"
               MockMarketplaceProvider.test_connection(settings: setting_credentials(setting))
    when "messaging"
               MockMessagingProvider.test_connection(settings: setting_credentials(setting))
    when "payment_gateway"
               MockPaymentGateway.test_connection(settings: setting_credentials(setting))
    else
               { success: false, message: "Provedor não suportado" }
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
    provider = creds[:provider] || "osm"
    
    case provider
    when "google"
      MockGoogleMapsProvider.test_connection(settings: creds) if creds[:api_key].present?
    else
      OsmMapsProvider.test_connection(settings: creds.except(:provider, :api_key))
    end
  rescue => e
    { success: false, message: "Erro: #{e.message}" }
  end
end
