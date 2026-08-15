require "rails_helper"

RSpec.describe "Cashier customer flow", type: :system do
  let(:business) { create(:business) }
  let(:cashier) { Tenancy.with_business(business) { create(:user, :cashier, business: business) } }

  before do
    driven_by :rack_test
    login_as cashier, scope: :user
    Tenancy.with_business(business) { create(:cash_register, :open, user: cashier, business: business) }
  end

  def with_tenancy(&block)
    Tenancy.with_business(business, &block)
  end

  it "attaches an existing customer, quick-creates a new one mid-order and renders history on the profile" do
    with_tenancy { create(:customer, business: business, name: "Maria Silva", phone: "11912345678") }
    with_tenancy do
      category = create(:category, business: business)
      create(:product, business: business, category: category, name: "X-Burger", price: 15.0)
    end

    visit "/pos"

    click_button "Adicionar"
    expect(page).to have_content("X-Burger adicionado ao pedido")

    select "Maria Silva", from: "customer_id"
    click_button "Vincular"
    expect(page).to have_content("Maria Silva vinculado ao pedido")
    expect(page).to have_content("11912345678")

    fill_in "Nome", with: "João Souza"
    fill_in "Telefone", with: "(11) 98877-6655"
    click_button "Criar cliente"
    expect(page).to have_content("João Souza criado e vinculado ao pedido")
    expect(page).to have_content("11988776655")

    click_button "Confirmar pedido"
    expect(page).to have_content("Pedido confirmado")

    fill_in "payment_amount", with: "15.00"
    click_button "Confirmar pagamento"
    expect(page).to have_content("Pagamento recebido")

    click_link "João Souza"
    expect(page).to have_content("Histórico de compras")
    expect(page).to have_content("R$ 15,00")
    expect(page).to have_content("Ticket médio")
  end
end
