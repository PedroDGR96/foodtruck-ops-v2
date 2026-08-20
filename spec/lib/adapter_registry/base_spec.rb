# frozen_string_literal: true

require "rails_helper"

RSpec.describe AdapterRegistry::Base do
  subject(:adapter) { described_class.new }

  it "raises NotImplementedError on authenticate" do
    expect { adapter.authenticate({}) }.to raise_error(NotImplementedError)
  end

  it "raises NotImplementedError on create_order" do
    expect { adapter.create_order({}) }.to raise_error(NotImplementedError)
  end

  it "raises NotImplementedError on get_order_status" do
    expect { adapter.get_order_status("x") }.to raise_error(NotImplementedError)
  end

  it "raises NotImplementedError on cancel_order" do
    expect { adapter.cancel_order("x") }.to raise_error(NotImplementedError)
  end
end
