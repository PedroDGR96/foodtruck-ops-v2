module ApplicationCable
  class Channel < ActionCable::Channel::Base
    def subscribe_to_channel
      with_business { super }
    end

    def perform_action(data)
      with_business { super }
    end

    private

    def with_business(&block)
      Tenancy.with_business(connection.business, &block)
    end
  end
end
