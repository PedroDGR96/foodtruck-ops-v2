require 'rails_helper'
require Rails.root.join('lib/adapter_registry/base')

RSpec.describe AdapterRegistry::Registry do
  describe '.register_adapter' do
    it 'registers an adapter for a given key' do
      mock = Object.new
      AdapterRegistry::Registry.register_adapter(:stripe, mock)
      expect(AdapterRegistry::Registry.adapters[:stripe]).to eq(mock)
    end

    it 'overregisters the same key with the new adapter' do
      old_mock = Object.new
      new_mock = Object.new
      AdapterRegistry::Registry.register_adapter(:stripe, old_mock)
      AdapterRegistry::Registry.register_adapter(:stripe, new_mock)
      expect(AdapterRegistry::Registry.adapters[:stripe]).to eq(new_mock)
    end
  end

  describe '.adapter_for' do
    it 'returns the registered adapter for a given key' do
      mock = Object.new
      AdapterRegistry::Registry.register_adapter(:stripe, mock)
      expect(AdapterRegistry::Registry.adapter_for(:stripe)).to eq(mock)
    end

    it 'raises an error for unregistered keys' do
      expect { AdapterRegistry::Registry.adapter_for(:unknown) }
        .to raise_error(AdapterRegistry::AdapterError, /No adapter registered/)
    end
  end

  describe '.adapters' do
    it 'returns a copy of the adapters hash' do
      mock = Object.new
      AdapterRegistry::Registry.register_adapter(:stripe, mock)
      result = AdapterRegistry::Registry.adapters
      expect(result[:stripe]).to eq(mock)
      # Modifying the returned hash should not affect the internal state
      result.delete(:stripe)
      expect(AdapterRegistry::Registry.adapters[:stripe]).to eq(mock)
    end
  end

  describe '.clear!' do
    it 'removes all registered adapters' do
      mock = Object.new
      AdapterRegistry::Registry.register_adapter(:stripe, mock)
      AdapterRegistry::Registry.clear!
      expect(AdapterRegistry::Registry.adapters).to be_empty
    end
  end
end
