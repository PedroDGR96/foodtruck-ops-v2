class OrderChannel < ApplicationCable::Channel
  def subscribed
    stream_from OrderChannel.stream_name(connection.business.id)
  end

  def self.stream_name(business_id)
    "orders_#{business_id}"
  end
end
