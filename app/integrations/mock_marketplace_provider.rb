# Deterministic, stateless mock for MarketplaceProvider simulating iFood's
# order lifecycle. Order numbers are derived from merchant id and platform
# via CRC32 for deterministic behavior in tests.
class MockMarketplaceProvider < MarketplaceProvider
  STATUSES = %w[pending confirmed preparing ready delivered cancelled].freeze

  def self.create_order(settings:, args:)
    merchant_id = args.fetch(:merchant_id)
    platform = args.fetch(:platform, "ifood")
    order_num = 1000 + (Zlib.crc32("#{merchant_id}#{platform}") % 9_000)
    code = generate_code(order_num)

    {
      success: true,
      message: "Pedido criado no #{platform}",
      data: {
        order_num: order_num,
        code: code,
        merchant_id: merchant_id,
        platform: platform,
        user_id: args[:user_id],
        customer_name: args[:customer_name] || "Cliente #{order_num}",
        items_count: args[:items_count] || 1,
        total_amount: args[:total_amount].to_f,
        delivery_fee: args[:delivery_fee].to_f,
        status: "pending",
        created_at: Time.current.iso8601,
        estimated_delivery: (Time.current + 45.minutes).iso8601
      }
    }
  end

  def self.update_order(settings:, args:)
    order_num = args.fetch(:order_num)
    status = args[:status] || "confirmed"

    {
      success: true,
      message: "Pedido #{order_num} atualizado para #{status}",
      data: {
        order_num: order_num,
        status: status,
        updated_at: Time.current.iso8601
      }
    }
  end

  def self.cancel_order(settings:, args:)
    order_num = args.fetch(:order_num)
    merchant_id = args.fetch(:merchant_id)
    reason = args[:reason] || "Cancelamento solicitado"

    {
      success: true,
      message: "Pedido #{order_num} cancelado no #{args[:platform] || 'ifood'}",
      data: {
        order_num: order_num,
        merchant_id: merchant_id,
        status: "cancelled",
        cancel_reason: reason,
        cancelled_at: Time.current.iso8601
      }
    }
  end

  def self.status(settings:, args:)
    order_num = args.fetch(:order_num)
    {
      success: true,
      message: "Status consultado",
      data: {
        order_num: order_num,
        status: args[:status] || "pending",
        updated_at: Time.current.iso8601
      }
    }
  end

  def self.webhook_verify(settings:, args:)
    token = settings[:webhook_token]
    received_token = args[:x_ifood_signature]

    {
      success: token.present? && token == received_token,
      message: token.present? ? "Webhook verificado" : "Token não configurado"
    }
  end

  def self.generate_code(order_num)
    chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    seed = order_num.to_s
    code = 6.times.map { chars[Zlib.crc32(seed + _1.to_s) % chars.length] }.join
    "IFO-#{code}"
  end
  private_class_method :generate_code
end
