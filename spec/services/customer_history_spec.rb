require "rails_helper"

RSpec.describe CustomerHistory do
  let(:business) { create(:business) }

  around do |example|
    Tenancy.with_business(business) { example.run }
  end

  def customer
    @customer ||= create(:customer, business: business)
  end

  def paid_order(total:)
    create(:order, :open, business: business, customer: customer, total: total, subtotal: total).tap do |order|
      create(:payment, order: order, amount: total)
      order.update!(status: :paid, payment_status: :paid)
    end
  end

  it "is empty for a customer with no purchases" do
    history = CustomerHistory.call(customer)

    expect(history.orders).to be_empty
    expect(history.order_count).to eq(0)
    expect(history.total_spent).to eq(0.0)
    expect(history.average_spend).to eq(0.0)
    expect(history.last_order).to be_nil
  end

  it "counts purchases and sums their totals" do
    paid_order(total: 30.0)
    create(:order, :open, business: business, customer: customer, total: 20.0, subtotal: 20.0)

    history = CustomerHistory.call(customer)

    expect(history.order_count).to eq(2)
    expect(history.total_spent).to eq(50.0)
    expect(history.average_spend).to eq(25.0)
  end

  it "excludes drafts, cancellations and refunds" do
    create(:order, business: business, customer: customer, total: 10.0, subtotal: 10.0)
    create(:order, :cancelled, business: business, customer: customer, total: 10.0, subtotal: 10.0)
    create(:order, :open, business: business, customer: customer, total: 15.0, subtotal: 15.0)

    history = CustomerHistory.call(customer)

    expect(history.order_count).to eq(1)
    expect(history.total_spent).to eq(15.0)
  end

  it "identifies the most recent order as the last one" do
    older = create(:order, :open, business: business, customer: customer, total: 10.0, subtotal: 10.0, created_at: 2.days.ago)
    recent = create(:order, :open, business: business, customer: customer, total: 20.0, subtotal: 20.0)

    history = CustomerHistory.call(customer)

    expect(history.last_order.id).to eq(recent.id)
    expect(history.orders.map(&:id)).to eq([ recent.id, older.id ])
  end
end
