module IntegrationsHelper
  def provider_fields(provider_key)
    case provider_key
    when "payment_gateway"
      [
        { key: "public_key", type: :text, placeholder: "APP_USR-..." },
        { key: "access_token", type: :password, placeholder: "••••••••" },
        { key: "webhook_secret", type: :password, placeholder: "••••••••" },
        { key: "sandbox", type: :select, options: [ [ "Sim", "true" ], [ "Não", "false" ] ] }
      ]
    when "messaging"
      [
        { key: "twilio_account_sid", type: :text, placeholder: "AC..." },
        { key: "twilio_auth_token", type: :password, placeholder: "••••••••" },
        { key: "twilio_phone", type: :text, placeholder: "+5511999999999" },
        { key: "whatsapp_business_token", type: :password, placeholder: "••••••••" },
        { key: "whatsapp_phone_id", type: :text, placeholder: "ID do telefone" }
      ]
    when "maps"
      [
        { key: "provider", type: :select, options: [ [ "OpenStreetMap (gratuito)", "osm" ], [ "Google Maps", "google" ] ] },
        { key: "api_key", type: :password, placeholder: "Chave da API (se Google Maps)" },
        { key: "default_origin", type: :text, placeholder: "Endereço base da food truck" }
      ]
    when "fiscal"
      [
        { key: "environment", type: :select, options: [ [ "Homologação", "homologacao" ], [ "Produção", "producao" ] ] },
        { key: "state", type: :select, options: %w[AC AL AM AP BA CE DF ES GO MA MG MS MT PA PB PE PI PR RJ RN RO RR RS SC SE SP TO].map { |s| [ s, s ] } },
        { key: "cnpj", type: :text, placeholder: "00.000.000/0001-00" },
        { key: "certificate_path", type: :text, placeholder: "/certs/certificado.pfx" },
        { key: "certificate_password", type: :password, placeholder: "••••••••" }
      ]
    when "marketplace"
      [
        { key: "merchant_id", type: :text, placeholder: "ID do estabelecimento" },
        { key: "platform", type: :select, options: [ [ "iFood", "ifood" ], [ "99Food", "99food" ], [ "Rappi", "rappi" ] ] },
        { key: "api_key", type: :password, placeholder: "••••••••" },
        { key: "webhook_token", type: :password, placeholder: "••••••••" }
      ]
    else
      []
    end
  end
end
