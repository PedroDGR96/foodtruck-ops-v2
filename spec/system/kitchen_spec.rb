require "rails_helper"

RSpec.describe "Kitchen display flow", type: :system do
  let(:business) { create(:business) }
  let(:kitchen) { Tenancy.with_business(business) { create(:user, :kitchen, business: business) } }

  before do
    driven_by :rack_test
    login_as kitchen, scope: :user
  end

  def within_tenant(&block)
    Tenancy.with_business(business, &block)
  end

  def paid_order(status: "paid", kitchen_status: "pending", **attrs)
    within_tenant do
      o = create(:order, :open, business: business, total: 10.0, subtotal: 10.0)
      create(:payment, order: o, amount: 10.0)
      o.update!(status: status, payment_status: :paid, kitchen_status: kitchen_status, **attrs)
      o
    end
  end

  it "shows a paid order on the KDS and removes it from the queue once marked done" do
    order = paid_order(status: "paid", kitchen_status: "pending")

    visit "/kitchen"

    expect(page).to have_css("#order_#{order.id}")
    expect(page).to have_content("##{order.id}")

    click_button I18n.t("kitchen.start")
    expect(within_tenant { order.reload }).to be_in_kitchen

    click_button I18n.t("kitchen.ready_btn")
    expect(page).to have_css("#completed_order_#{order.id}")
    expect(page).not_to have_css("#order_#{order.id}")
    expect(within_tenant { order.reload }).to be_ready
  end

  it "renders overdue state for a ticket past the prep threshold" do
    paid_order(status: "in_kitchen", kitchen_status: "in_progress", started_at: 20.minutes.ago)

    visit "/kitchen"

    expect(page).to have_css(".is-overdue")
    expect(page.html).to include(I18n.t("kitchen.overdue"))
  end

  it "keeps sound off by default so playback requires an explicit gesture" do
    paid_order(status: "paid", kitchen_status: "pending")

    visit "/kitchen"

    sound = find("[data-controller='kitchen-sound']")
    expect(sound["data-kitchen-sound-enabled-value"]).to eq("false")
    expect(sound["aria-pressed"]).to eq("false")
    expect(sound).to have_content(I18n.t("kitchen.sound_off"))
    expect(page).not_to have_selector("audio[autoplay]")
  end

  it "shows customer and address for a delivery order and counts the rail" do
    within_tenant do
      maria = create(:customer, business: business, name: "Maria Silva")
      o = create(:order, :open, business: business, customer: maria,
        total: 12.0, subtotal: 10.0, delivery_fee: 2.0)
      o.order_type = "delivery"
      o.build_delivery_address(
        street: "Rua Augusta", number: "455", neighborhood: "Consolação",
        city: "São Paulo", state: "SP"
      )
      o.save!
      create(:payment, order: o, amount: 12.0)
      o.update!(status: "in_kitchen", payment_status: :paid, kitchen_status: "in_progress")
    end

    visit "/kitchen"

    expect(page).to have_content(I18n.t("kitchen.customer"))
    expect(page).to have_content("Maria Silva")
    expect(page).to have_content(I18n.t("kitchen.address"))
    expect(page).to have_content("Rua Augusta, 455")
    expect(page).to have_content("Consolação, São Paulo - SP")
    expect(page).to have_css("#kitchen-queue-delivery")
    expect(page).to have_content("(1)")
  end

  it "shows addons on completed tickets" do
    within_tenant do
      product = create(:product, business: business, price: 5.0)
      o = create(:order, :open, business: business, total: 7.5, subtotal: 7.5)
      item = create(:order_item, order: o, product: product, product_name: "X-Burger",
        unit_price: 5.0, quantity: 1, line_total: 7.5)
      create(:order_item_addon, order_item: item, name: "Queijo", price: 2.5)
      create(:payment, order: o, amount: 7.5)
      o.update!(status: "ready", payment_status: :paid, kitchen_status: "done", finished_at: Time.current)
    end

    visit "/kitchen"

    expect(page).to have_content("+ Queijo")
  end
end
