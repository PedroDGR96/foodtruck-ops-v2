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
end
