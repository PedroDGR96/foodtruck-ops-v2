require_relative "base"

module AdapterRegistry
  module Registry
    class << self
      def register_adapter(key, adapter)
        internal_adapters[key] = adapter
      end

      def adapter_for(key)
        internal_adapters.fetch(key) { raise AdapterError, "No adapter registered for #{key}" }
      end

      def adapters
        internal_adapters.dup
      end

      def clear!
        @adapters = {}
      end

      private

      def internal_adapters
        @adapters ||= {}
      end
    end
  end
end
