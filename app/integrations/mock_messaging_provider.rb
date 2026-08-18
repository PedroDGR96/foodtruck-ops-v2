# Deterministic, stateless mock for MessagingProvider. Messages are never
# delivered anywhere; every send returns a success Hash and the SMS branch
# reports a stable cost based on 160-character segment counting.
class MockMessagingProvider < MessagingProvider
  SMS_SEGMENT_COST = 0.05
  SMS_SEGMENT_SIZE = 160
  WHATSAPP_COST_PER_MESSAGE = 0.005

  def self.send_whatsapp(settings:, phone:, message:)
    validate_message!(message)
    validate_phone!(phone)

    {
      success: true,
      message: "WhatsApp message queued for #{phone}",
      cost: WHATSAPP_COST_PER_MESSAGE
    }
  end

  def self.send_sms(settings:, phone:, message:)
    validate_message!(message)
    validate_phone!(phone)

    segments = [ (message.length.to_f / SMS_SEGMENT_SIZE).ceil, 1 ].max
    cost = (segments * SMS_SEGMENT_COST).round(2)

    {
      success: true,
      message: "SMS queued for #{phone}",
      cost: cost,
      segments: segments
    }
  end

  def self.send_email(settings:, email:, message:, subject: nil)
    validate_message!(message)
    validate_email!(email)

    {
      success: true,
      message: "Email queued for #{email}",
      subject: subject
    }
  end

  def self.bulk_send(settings:, messages:)
    messages.map do |msg|
      case msg[:type].to_s
      when "whatsapp"
        send_whatsapp(settings: settings, phone: msg.fetch(:to), message: msg.fetch(:body))
      when "sms"
        send_sms(settings: settings, phone: msg.fetch(:to), message: msg.fetch(:body))
      when "email"
        send_email(settings: settings, email: msg.fetch(:to), subject: msg[:subject] || "", message: msg.fetch(:body))
      else
        { success: false, message: "Unsupported message type: #{msg[:type]}" }
      end
    rescue KeyError => e
      { success: false, message: "Malformed: #{e.message}" }
    end
  end

  def self.validate_message!(message)
    raise ArgumentError, "Message cannot be empty" if message.nil? || message.strip.empty?
  end
  private_class_method :validate_message!

  def self.validate_phone!(phone)
    # Accept both E.164 (+55...) and local format (55119...)
    raise ArgumentError, "Invalid phone" unless phone.match?(/\A\+?\d{5,15}\z/)
  end
  private_class_method :validate_phone!

  def self.validate_email!(email)
    raise ArgumentError, "Invalid email" unless email.match?(/\A[^@\s]+@[^@\s]+\z/)
  end
  private_class_method :validate_email!
end
