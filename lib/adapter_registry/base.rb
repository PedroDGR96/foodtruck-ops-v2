module AdapterRegistry
  class AdapterError < StandardError; end

  class Base
    def authenticate(_credentials)
      raise NotImplementedError
    end

    def create_order(_order_params)
      raise NotImplementedError
    end

    def get_order_status(_order_id)
      raise NotImplementedError
    end

    def cancel_order(_order_id)
      raise NotImplementedError
    end
  end
end
