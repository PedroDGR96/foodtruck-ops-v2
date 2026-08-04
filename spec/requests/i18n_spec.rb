require "rails_helper"

RSpec.describe "Internationalization (pt-BR)", type: :request do
  let(:business) { create(:business) }

  def owner
    @owner ||= Tenancy.with_business(business) { create(:user, :owner, business: business) }
  end

  describe "locale configuration" do
    it "uses Brazilian Portuguese as the default locale" do
      expect(I18n.default_locale).to eq(:"pt-BR")
      expect(I18n.available_locales).to include(:"pt-BR")
    end

    it "resolves model and validation messages in Portuguese" do
      expect(User.human_attribute_name(:name)).to eq("Nome")
      expect(I18n.t("errors.messages.blank")).to eq("não pode ficar em branco")
    end

    it "formats money as BRL with the pt-BR convention" do
      helpers = ApplicationController.helpers
      expect(helpers.format_money(1234.56)).to eq("R$ 1.234,56")
      expect(helpers.format_money(0.5)).to eq("R$ 0,50")
    end

    it "formats dates and datetimes in the business timezone" do
      helpers = ApplicationController.helpers
      expect(helpers.format_date(Date.new(2026, 8, 3))).to eq("03/08/2026")
      expect(helpers.format_datetime(Time.zone.local(2026, 8, 3, 21, 15))).to eq("03/08/2026 21:15")
    end
  end

  describe "user-facing pages" do
    it "renders the sign in page in Portuguese" do
      get new_user_session_path

      expect(response.body).to include("Acessar sua empresa")
      expect(response.body).to include("Entrar")
      expect(response.body).not_to include("Log in to your workspace")
      expect(response.body).not_to include("Sign in")
    end

    it "renders the home page in Portuguese for an owner" do
      login_as owner, scope: :user
      get "/"

      expect(response.body).to include("Bem-vindo")
      expect(response.body).to include("Sair")
      expect(response.body).not_to include("Welcome")
      expect(response.body).not_to include("Sign out")
    end

    it "renders the staff index page in Portuguese" do
      login_as owner, scope: :user
      get "/users"

      expect(response.body).to include("Equipe")
      expect(response.body).to include("Adicionar membro da equipe")
      expect(response.body).not_to include("Staff")
    end

    it "renders the settings page in Portuguese" do
      login_as owner, scope: :user
      get "/settings/edit"

      expect(response.body).to include("Configurações da empresa")
      expect(response.body).to include("Salvar configurações")
      expect(response.body).not_to include("Business settings")
    end

    it "renders the forbidden page in Portuguese" do
      cashier = Tenancy.with_business(business) { create(:user, :cashier, business: business) }
      login_as cashier, scope: :user
      get "/users"

      expect(response).to have_http_status(:forbidden)
      expect(response.body).to include("Acesso negado")
      expect(response.body).not_to include("You are not allowed")
    end

    it "renders flash notices in Portuguese" do
      login_as owner, scope: :user
      target = Tenancy.with_business(business) { create(:user, :cashier, business: business) }

      patch "/users/#{target.id}", params: { user: { name: "Renomeado" } }

      expect(response).to redirect_to("/users")
      follow_redirect!
      expect(response.body).to include("Membro Renomeado atualizado.")
    end
  end
end
