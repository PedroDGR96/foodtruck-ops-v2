# The kitchen display subscribes to its own stream (kitchen_<business_id>) so
# ticket updates never collide with the orders page, which listens on the
# orders_<business_id> stream via OrderChannel.
class KitchenChannel < ApplicationCable::Channel
  def subscribed
    stream_from KitchenChannel.stream_name(connection.business.id)
  end

  def self.stream_name(business_id)
    "kitchen_#{business_id}"
  end
end
