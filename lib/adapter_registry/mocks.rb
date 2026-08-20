require_relative "base"

module AdapterRegistry::Mocks
  class StripeMock < AdapterRegistry::Base
    def authenticate(credentials)
      raise AdapterRegistry::AdapterError, "Invalid credentials" unless credentials[:stripe_api_key]
      { token: credentials[:stripe_api_key], expires_at: Time.now.to_i + 60 }
    end

    def create_order(order_params)
      raise AdapterRegistry::AdapterError, "Missing required fields" unless order_params[:customer_id] && order_params[:amount]
      { id: "mock_stpi_#{SecureRandom.hex(4)}", status: "pending", amount: order_params[:amount], customer_id: order_params[:customer_id] }
    end

    def get_order_status(order_id)
      raise AdapterRegistry::AdapterError, "Order not found" unless order_id.start_with?("mock_stpi_")
      { id: order_id, status: "completed" }
    end

    def cancel_order(order_id)
      raise AdapterRegistry::AdapterError, "Order not found" unless order_id.start_with?("mock_stpi_")
      { id: order_id, status: "cancelled" }
    end
  end

  class PayPalMock < AdapterRegistry::Base
    def authenticate(credentials)
      raise AdapterRegistry::AdapterError, "Invalid credentials" unless credentials[:paypal_token]
      { token: credentials[:paypal_token], expires_at: Time.now.to_i + 60 }
    end

    def create_order(order_params)
      raise AdapterRegistry::AdapterError, "Missing required fields" unless order_params[:customer_id] && order_params[:amount]
      { id: "mock_paypal_#{SecureRandom.hex(4)}", status: "pending", amount: order_params[:amount], customer_id: order_params[:customer_id] }
    end

    def get_order_status(order_id)
      raise AdapterRegistry::AdapterError, "Order not found" unless order_id.start_with?("mock_paypal_")
      { id: order_id, status: "completed" }
    end

    def cancel_order(order_id)
      raise AdapterRegistry::AdapterError, "Order not found" unless order_id.start_with?("mock_paypal_")
      { id: order_id, status: "cancelled" }
    end
  end
end
