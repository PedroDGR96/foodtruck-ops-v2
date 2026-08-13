# Contract for fiscal providers emitting Brazilian fiscal documents (NFC-e
# for POS sales, NF-e for invoices).
class FiscalProvider
  def self.emit_nfc_e(settings:, args:)
    raise NotImplementedError
  end

  def self.emit_nf_e(settings:, args:)
    raise NotImplementedError
  end
end
