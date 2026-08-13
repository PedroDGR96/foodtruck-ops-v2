# Deterministic, stateless mock for MarketplaceProvider. Order numbers are
# derived from merchant id and platform (via a stable CRC32) so the same
# intake always yields the same order number.
class MockMarketplaceProvider < MarketplaceProvider
  def self.create_order(settings:, args:)
    merchant_id = args.fetch(:merchant_id)
    platform = args.fetch(:platform)
    order_num = 1000 + (Zlib.crc32("#{merchant_id}#{platform}") % 9_000)

    {
      success: true,
      message: "Order created on #{platform}",
      data: {
        order_num: order_num,
        merchant_id: merchant_id,
        platform: platform,
        user_id: args[:user_id],
        items_count: args[:items_count],
        total_amount: args[:total_amount].to_f,
        status: "pending"
      }
    }
  end

  def self.update_order(settings:, args:)
    {
      success: true,
      message: "Order #{args[:order_num]} updated",
      data: {
        order_num: args.fetch(:order_num),
        status: args[:status] || "pending"
      }
    }
  end

  def self.cancel_order(settings:, args:)
    {
      success: true,
      message: "Order #{args[:order_num]} cancelled on #{args[:merchant_id]}",
      data: {
        order_num: args.fetch(:order_num),
        merchant_id: args.fetch(:merchant_id),
        status: "cancelled"
      }
    }
  end
end
