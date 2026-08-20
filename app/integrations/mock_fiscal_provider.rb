# Deterministic, stateless mock for FiscalProvider. Document numbers are
# derived from the order id unless the caller supplies one explicitly, so
# emissions are repeatable.
class MockFiscalProvider < FiscalProvider
  def self.emit_nfc_e(settings:, args:)
    number = args[:nfc_e_number] || "NFCe-#{args.fetch(:order_id)}"
    {
      success: true,
      message: "NFC-e emitted for order #{args[:order_id]}",
      data: {
        order_id: args[:order_id],
        payment_method: args[:payment_method],
        total_amount: args[:total_amount].to_f,
        nfc_e_number: number,
        status: "emitted"
      }
    }
  end

  def self.emit_nf_e(settings:, args:)
    number = args[:nf_e_number] || "NFe-#{args.fetch(:order_id)}"
    {
      success: true,
      message: "NF-e emitted for order #{args[:order_id]}",
      data: {
        order_id: args[:order_id],
        payment_method: args[:payment_method],
        total_amount: args[:total_amount].to_f,
        nf_e_number: number,
        status: "emitted"
      }
    }
  end

  def self.status(settings:, args:)
    {
      success: true,
      message: "Document status queried",
      data: {
        access_key: args[:access_key],
        status: "authorized"
      }
    }
  end

  def self.cancel(settings:, args:)
    {
      success: true,
      message: "Document cancelled",
      data: {
        access_key: args[:access_key],
        status: "cancelled"
      }
    }
  end
end
