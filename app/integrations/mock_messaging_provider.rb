# Deterministic, stateless mock for MessagingProvider. Messages are never
# delivered anywhere; every send returns a success Hash and the SMS branch
# reports a stable cost based on 160-character segment counting.
class MockMessagingProvider < MessagingProvider
  SMS_SEGMENT_COST = 0.05

  def self.send_whatsapp(settings:, phone:, message:)
    validate!(message)
    { success: true, message: "WhatsApp message queued for #{phone}" }
  end

  def self.send_sms(settings:, phone:, message:)
    validate!(message)
    segments = [ (message.length.to_f / 160).ceil, 1 ].max
    cost = (segments * SMS_SEGMENT_COST).round(2)
    { success: true, message: "SMS queued for #{phone}", cost: cost }
  end

  def self.send_email(settings:, email:, message:)
    validate!(message)
    { success: true, message: "Email queued for #{email}" }
  end

  def self.bulk_send(settings:, messages:)
    messages.map do |message|
      case message[:type].to_s
      when "whatsapp"
        send_whatsapp(settings: settings, phone: message.fetch(:to), message: message.fetch(:body))
      when "sms"
        send_sms(settings: settings, phone: message.fetch(:to), message: message.fetch(:body))
      when "email"
        send_email(settings: settings, email: message.fetch(:to), message: message.fetch(:body))
      else
        { success: false, message: "Unsupported message type: #{message[:type]}" }
      end
    rescue KeyError => e
      { success: false, message: "Malformed message: #{e.message}" }
    end
  end

  def self.validate!(message)
    raise ArgumentError, "Message cannot be empty" if message.nil? || message.strip.empty?
  end
  private_class_method :validate!
end
