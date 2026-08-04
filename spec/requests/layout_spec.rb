require "rails_helper"

RSpec.describe "App shell", type: :request do
  let(:business) { create(:business) }

  def staff(role)
    Tenancy.with_business(business) { create(:user, role, business: business) }
  end

  it "renders the back-office navigation for the owner" do
    login_as staff(:owner), scope: :user
    get "/"

    expect(response.body).to include("Equipe")
    expect(response.body).to include("Configurações")
    expect(response.body).to include("Sair")
  end

  it "renders the POS/KDS bottom bar for cashiers and kitchen staff" do
    [ :cashier, :kitchen ].each do |role|
      login_as staff(role), scope: :user
      get "/"

      expect(response.body).to include("Início")
      expect(response.body).to include(I18n.t("roles.#{role}"))
      expect(response.body).not_to include("Equipe")
      logout(:user)
    end
  end

  it "renders theme, toast and loading hooks in the base layout" do
    login_as staff(:owner), scope: :user
    get "/"

    expect(response.body).to include('data-controller="dark-mode"')
    expect(response.body).to include('data-controller="loading shortcuts"')
    expect(response.body).to include("skip-link")
    expect(response.body).to include('<div id="toasts"')
  end
end
