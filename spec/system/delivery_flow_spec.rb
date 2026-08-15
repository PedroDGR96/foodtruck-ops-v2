require "rails_helper"

RSpec.describe "Cashier delivery flow", type: :system do
  let(:business) { create(:business) }
  let(:cashier) { Tenancy.with_business(business) { create(:user, :cashier, business: business) } }

  before do
    driven_by :rack_test
    login_as cashier, scope: :user
    Tenancy.with_business(business) { business.update!(delivery_fee: 8.0) }
    Tenancy.with_business(business) { create(:cash_register, :open, user: cashier, business: business) }
  end

  def with_tenancy(&block)
    Tenancy.with_business(business, &block)
  end

  it "switches to delivery, fills the address, confirms and shows the delivery info" do
    with_tenancy do
      category = create(:category, business: business)
      create(:product, business: business, category: category, name: "X-Burger", price: 20.0)
    end

    visit "/pos"

    click_button "Adicionar"
    expect(page).to have_content("X-Burger adicionado ao pedido")

    select "Entrega", from: "order_order_type"
    fill_in "order[delivery_address][street]", with: "Rua das Flores"
    fill_in "order[delivery_address][number]", with: "100"
    fill_in "order[delivery_address][neighborhood]", with: "Centro"
    fill_in "order[delivery_address][city]", with: "São Paulo"
    fill_in "order[delivery_address][state]", with: "SP"

    click_button "Confirmar pedido"
    expect(page).to have_content("Pedido confirmado")

    fill_in "payment_amount", with: "28.00"
    click_button "Confirmar pagamento"
    expect(page).to have_content("Pagamento recebido")

    with_tenancy do
      order = Order.last
      expect(order).to be_delivery
      expect(order.delivery_fee).to eq(8.0)
      expect(order.total).to eq(28.0)
      expect(order.delivery_address).to be_present
      expect(order.delivery).to be_pending
    end

    expect(page).to have_content("Rua das Flores")
    expect(page).to have_content("Pendente")
  end
end
