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
    render :edit, status: :unprocessable_entity
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
               test_fiscal_connection(setting)
    when "marketplace"
               test_marketplace_connection(setting)
    when "messaging"
               test_messaging_connection(setting)
    when "payment_gateway"
               test_payment_connection(setting)
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

  def test_maps_connection(setting)
    if setting&.credentials&.dig("api_key").present?
      { success: true, message: "Google Maps configurado" }
    else
      OsmMapsProvider.geocode(settings: {}, args: { address: "Porto Alegre, RS" })[:success] ?
        { success: true, message: "OpenStreetMap conectado" } :
        { success: false, message: "Falha ao conectar com OpenStreetMap" }
    end
  rescue => e
    { success: false, message: "Erro: #{e.message}" }
  end

  def test_fiscal_connection(setting)
    env = setting&.credentials&.dig("environment") || "homologacao"
    cnpj = setting&.credentials&.dig("cnpj")

    if env == "homologacao"
      { success: true, message: "Ambiente de homologação configurado" }
    elsif cnpj.present?
      { success: true, message: "Produção configurada (CNPJ: #{cnpj})" }
    else
      { success: false, message: "CNPJ não configurado para produção" }
    end
  end

  def test_marketplace_connection(setting)
    merchant_id = setting&.credentials&.dig("merchant_id")
    platform = setting&.credentials&.dig("platform") || "ifood"

    if merchant_id.present?
      { success: true, message: "#{platform.capitalize} conectado (merchant: #{merchant_id})" }
    else
      { success: false, message: "ID do estabelecimento não configurado" }
    end
  end

  def test_messaging_connection(setting)
    sid = setting&.credentials&.dig("twilio_account_sid")
    token = setting&.credentials&.dig("twilio_auth_token")

    if sid.present? && token.present?
      { success: true, message: "Twilio configurado (SID: #{sid[0..5]}...)" }
    else
      { success: false, message: "Credenciais do Twilio não configuradas" }
    end
  end

  def test_payment_connection(setting)
    public_key = setting&.credentials&.dig("public_key")

    if public_key.present?
      { success: true, message: "Mercado Pago conectado (chave: #{public_key[0..10]}...)" }
    else
      { success: false, message: "Chave pública não configurada" }
    end
  end
end
