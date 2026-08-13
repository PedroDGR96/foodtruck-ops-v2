# Contract for messaging providers (WhatsApp, SMS, email and bulk sends).
class MessagingProvider
  def self.send_whatsapp(settings:, phone:, message:)
    raise NotImplementedError
  end

  def self.send_sms(settings:, phone:, message:)
    raise NotImplementedError
  end

  def self.send_email(settings:, email:, message:)
    raise NotImplementedError
  end

  def self.bulk_send(settings:, messages:)
    raise NotImplementedError
  end
end
