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
        { key: "whatsapp_phone_id", type: :text, placeholder: "ID do telefone" },
        { key: "smtp_host", type: :text, placeholder: "smtp.example.com" },
        { key: "smtp_port", type: :text, placeholder: "587" },
        { key: "smtp_user", type: :text, placeholder: "usuário SMTP (opcional)" },
        { key: "smtp_password", type: :password, placeholder: "••••••••" },
        { key: "smtp_from", type: :text, placeholder: "no-reply@exemplo.com" }
      ]
    when "maps"
      [
        { key: "default_origin", type: :text, placeholder: "Endereço base da food truck" }
      ]
    when "fiscal"
      [
        { key: "environment", type: :select, options: [ [ "Homologação", "homologacao" ], [ "Produção", "producao" ] ] },
        { key: "token", type: :password, placeholder: "Token Focus NFe (U/v...)" },
        { key: "state", type: :select, options: %w[AC AL AM AP BA CE DF ES GO MA MG MS MT PA PB PE PI PR RJ RN RO RR RS SC SE SP TO].map { |s| [ s, s ] } },
        { key: "cnpj", type: :text, placeholder: "00.000.000/0001-00" },
        { key: "certificate_path", type: :text, placeholder: "/certs/certificado.pfx" },
        { key: "certificate_password", type: :password, placeholder: "••••••••" }
      ]
    when "marketplace"
      [
        { key: "client_id", type: :text, placeholder: "Client ID (developer portal)" },
        { key: "client_secret", type: :password, placeholder: "Client secret" },
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
