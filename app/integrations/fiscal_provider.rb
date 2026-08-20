# Contract for fiscal providers emitting Brazilian fiscal documents (NFC-e
# for POS sales, NF-e for invoices). Subclasses implement the actual SEFAZ
# integration; the mock provides deterministic sandbox behavior.
class FiscalProvider
  # @param settings [Hash] provider configuration (certificate, endpoint, etc.)
  # @param args [Hash] document-specific data
  # @return [Hash] { success:, message:, data: { nfc_e_number:, status:, ... } }
  def self.emit_nfc_e(settings:, args:)
    raise NotImplementedError
  end

  def self.emit_nf_e(settings:, args:)
    raise NotImplementedError
  end

  def self.status(settings:, args:)
    raise NotImplementedError
  end

  def self.cancel(settings:, args:)
    raise NotImplementedError
  end
end
