require 'rails_helper'
require Rails.root.join('lib/adapter_registry/base')

RSpec.describe AdapterRegistry::Base do
  subject(:base) { described_class.new }

  %i[authenticate create_order get_order_status cancel_order].each do |method|
    describe "##{method}" do
      it 'raises NotImplementedError' do
        expect { base.public_send(method, {}) }.to raise_error(NotImplementedError)
      end
    end
  end
end
