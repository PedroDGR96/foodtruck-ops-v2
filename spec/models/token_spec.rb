require "rails_helper"

RSpec.describe Token, type: :model do
  let(:business) { create(:business) }
  let(:user) { Tenancy.with_business(business) { create(:user, :owner, business: business) } }

  describe ".issue!" do
    it "persists a token, records the business and returns the raw value" do
      token, raw = Token.issue!(user: user, scope: "writer", name: "cli")

      expect(token).to be_persisted
      expect(token.business).to eq(business)
      expect(token.user).to eq(user)
      expect(token.scope).to eq("writer")
      expect(token.name).to eq("cli")
      expect(token.active).to be(true)
      expect(raw).to be_present
      expect(token.token_digest).to eq(Token.digest(raw))
      expect(token.token_digest).not_to eq(raw)
    end

    it "generates a digest even when none is provided" do
      token = Token.new(user: user, scope: "admin", name: "cli")
      token.save!

      expect(token.token_digest).to be_present
      expect(token.token_digest).not_to be_empty
    end

    it "rejects invalid scopes and blank names" do
      expect { Token.issue!(user: user, scope: "superuser", name: "cli") }.to raise_error(ActiveRecord::RecordInvalid)
      expect { Token.issue!(user: user, scope: "reader", name: "") }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe ".authenticate" do
    it "finds a token by its raw value" do
      token, raw = Token.issue!(user: user, scope: "admin", name: "cli")

      expect(Token.authenticate(raw)).to eq(token)
    end

    it "returns nil for blank or unknown values" do
      expect(Token.authenticate(nil)).to be_nil
      expect(Token.authenticate("")).to be_nil
      expect(Token.authenticate("not-a-real-token")).to be_nil
    end
  end

  describe "#expired?" do
    it "is true only when the token has an expiration in the past" do
      fresh, _raw = Token.issue!(user: user, scope: "reader", name: "cli")
      expired, _raw = Token.issue!(user: user, scope: "reader", name: "expired")
      expired.update_column(:expires_at, 1.hour.ago)

      expect(fresh.expired?).to be(false)
      expect(expired.expired?).to be(true)
    end
  end

  describe "#touch_last_used!" do
    it "updates last_used_at without reloading" do
      token, _raw = Token.issue!(user: user, scope: "reader", name: "cli")
      expect(token.last_used_at).to be_nil

      token.touch_last_used!

      expect(token.reload.last_used_at).to be_present
    end
  end
end
