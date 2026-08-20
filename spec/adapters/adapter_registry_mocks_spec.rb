require 'rails_helper'
require Rails.root.join('lib/adapter_registry/base')
require Rails.root.join('lib/adapter_registry/mocks')

RSpec.describe AdapterRegistry::Mocks::StripeMock do
  let(:mock) { AdapterRegistry::Mocks::StripeMock.new }
  let(:credentials) { Hash[stripe_api_key: 'sk_test_123'] }
  let(:order_params) { Hash[customer_id: 'cus_abc', amount: 50.0, product_id: 'prod_xyz'] }

  describe '#authenticate' do
    it 'returns a token for valid credentials' do
      result = mock.authenticate(credentials)
      expect(result[:token]).to eq('sk_test_123')
      expect(result[:expires_at]).to be_a(Integer)
    end

    it 'raises an error for invalid credentials' do
      expect { mock.authenticate({}) }.to raise_error(AdapterRegistry::AdapterError, /Invalid credentials/)
    end
  end

  describe '#create_order' do
    it 'returns a mock order with pending status' do
      result = mock.create_order(order_params)
      expect(result[:id]).to start_with('mock_stpi_')
      expect(result[:status]).to eq('pending')
      expect(result[:amount]).to eq(50.0)
    end

    it 'raises an error for missing required fields' do
      expect { mock.create_order({}) }.to raise_error(AdapterRegistry::AdapterError, /Missing required fields/)
    end
  end

  describe '#get_order_status' do
    it 'returns a completed order status' do
      result = mock.get_order_status('mock_stpi_123')
      expect(result[:id]).to eq('mock_stpi_123')
      expect(result[:status]).to eq('completed')
    end

    it 'raises an error for unknown order IDs' do
      expect { mock.get_order_status('unknown_id') }.to raise_error(AdapterRegistry::AdapterError, /Order not found/)
    end
  end

  describe '#cancel_order' do
    it 'returns a cancelled order status' do
      result = mock.cancel_order('mock_stpi_123')
      expect(result[:id]).to eq('mock_stpi_123')
      expect(result[:status]).to eq('cancelled')
    end

    it 'raises an error for unknown order IDs' do
      expect { mock.cancel_order('unknown_id') }.to raise_error(AdapterRegistry::AdapterError, /Order not found/)
    end
  end
end

RSpec.describe AdapterRegistry::Mocks::PayPalMock do
  let(:mock) { AdapterRegistry::Mocks::PayPalMock.new }
  let(:credentials) { Hash[paypal_token: 'bearer_test'] }
  let(:order_params) { Hash[customer_id: 'cus_abc', amount: 50.0, product_id: 'prod_xyz'] }

  describe '#authenticate' do
    it 'returns a token for valid credentials' do
      result = mock.authenticate(credentials)
      expect(result[:token]).to eq('bearer_test')
      expect(result[:expires_at]).to be_a(Integer)
    end

    it 'raises an error for invalid credentials' do
      expect { mock.authenticate({}) }.to raise_error(AdapterRegistry::AdapterError, /Invalid credentials/)
    end
  end

  describe '#create_order' do
    it 'returns a mock order with pending status' do
      result = mock.create_order(order_params)
      expect(result[:id]).to start_with('mock_paypal_')
      expect(result[:status]).to eq('pending')
      expect(result[:amount]).to eq(50.0)
    end

    it 'raises an error for missing required fields' do
      expect { mock.create_order({}) }.to raise_error(AdapterRegistry::AdapterError, /Missing required fields/)
    end
  end

  describe '#get_order_status' do
    it 'returns a completed order status' do
      result = mock.get_order_status('mock_paypal_123')
      expect(result[:id]).to eq('mock_paypal_123')
      expect(result[:status]).to eq('completed')
    end

    it 'raises an error for unknown order IDs' do
      expect { mock.get_order_status('unknown_id') }.to raise_error(AdapterRegistry::AdapterError, /Order not found/)
    end
  end

  describe '#cancel_order' do
    it 'returns a cancelled order status' do
      result = mock.cancel_order('mock_paypal_123')
      expect(result[:id]).to eq('mock_paypal_123')
      expect(result[:status]).to eq('cancelled')
    end

    it 'raises an error for unknown order IDs' do
      expect { mock.cancel_order('unknown_id') }.to raise_error(AdapterRegistry::AdapterError, /Order not found/)
    end
  end
end
