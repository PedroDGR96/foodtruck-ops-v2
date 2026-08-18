# Contract for messaging providers (WhatsApp Business, SMS via Twilio,
# email via ActionMailer). Subclasses implement provider-specific APIs;
# the mock provides deterministic sandbox behavior for tests.
class MessagingProvider
  # @param settings [Hash] provider config (api_key, from_number, etc.)
  # @param phone [String] recipient phone in E.164 format
  # @param message [String] message body
  # @return [Hash] { success:, message:, cost: (optional) }
  def self.send_whatsapp(settings:, phone:, message:)
    raise NotImplementedError
  end

  def self.send_sms(settings:, phone:, message:)
    raise NotImplementedError
  end

  def self.send_email(settings:, email:, message:, subject: nil)
    raise NotImplementedError
  end

  def self.bulk_send(settings:, messages:)
    raise NotImplementedError
  end
end
