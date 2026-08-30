# frozen_string_literal: true

require "rails_helper"

RSpec.describe CashRegisterService do
  let(:business) { create(:business) }
  let(:user) { create(:user, business: business) }

  describe ".open!" do
    it "persists the opening balance on an open register" do
      Tenancy.with_business(business) do
        register = CashRegister.create!(
          user: user,
          business: business,
          status: :open,
          opening_amount: 250.00,
          opened_at: Time.current
        )

        result = described_class.open!(register: register, actor: user)

        expect(result).to eq(register)
        expect(register.reload.opening_amount).to eq(250.00)
      end
    end

    it "raises when the register is not open" do
      Tenancy.with_business(business) do
        register = CashRegister.create!(
          user: user,
          business: business,
          status: :closed,
          opening_amount: 10.00,
          opened_at: Time.current,
          actual_closing_amount: 10.00,
          closed_at: Time.current
        )

        expect { described_class.open!(register: register) }.to raise_error(ArgumentError, "Register already open")
      end
    end
  end

  describe ".record_movement!" do
    it "records an income movement and adds to expected closing" do
      Tenancy.with_business(business) do
        register = CashRegister.create!(
          user: user,
          business: business,
          status: :open,
          opening_amount: 100.00,
          opened_at: Time.current
        )

        movement = described_class.record_movement!(
          register: register,
          movement_type: :income,
          category: :cash_drop,
          amount: 50.00,
          reason: "Cash drop",
          actor: user
        )

        expect(movement).to be_persisted
        expect(register.cash_movements.count).to eq(1)
        expect(register.expected_closing).to eq(150.00)
      end
    end

    it "records an expense movement and subtracts from expected closing" do
      Tenancy.with_business(business) do
        register = CashRegister.create!(
          user: user,
          business: business,
          status: :open,
          opening_amount: 100.00,
          opened_at: Time.current
        )

        movement = described_class.record_movement!(
          register: register,
          movement_type: :expense,
          category: :refund,
          amount: 25.00,
          reason: "Refund",
          actor: user
        )

        expect(movement).to be_persisted
        expect(register.cash_movements.count).to eq(1)
        expect(register.expected_closing).to eq(75.00)
      end
    end

    it "accumulates multiple movements into expected closing" do
      Tenancy.with_business(business) do
        register = CashRegister.create!(
          user: user,
          business: business,
          status: :open,
          opening_amount: 100.00,
          opened_at: Time.current
        )

        described_class.record_movement!(
          register: register,
          movement_type: :income,
          category: :cash_drop,
          amount: 50.00,
          reason: "Cash drop",
          actor: user
        )

        described_class.record_movement!(
          register: register,
          movement_type: :expense,
          category: :payout,
          amount: 20.00,
          reason: "Payout",
          actor: user
        )

        expect(register.cash_movements.count).to eq(2)
        expect(register.expected_closing).to eq(130.00)
      end
    end

    it "records the movement with the provided category and reason" do
      Tenancy.with_business(business) do
        register = CashRegister.create!(
          user: user,
          business: business,
          status: :open,
          opening_amount: 100.00,
          opened_at: Time.current
        )

        movement = described_class.record_movement!(
          register: register,
          movement_type: :income,
          category: :other_income,
          amount: 15.00,
          reason: "Other income",
          actor: user
        )

        expect(movement.category).to eq("other_income")
        expect(movement.reason).to eq("Other income")
        expect(movement.amount).to eq(15.00)
      end
    end
  end

  describe ".close!" do
    it "closes the register with actual closing amount and computes drift" do
      Tenancy.with_business(business) do
        register = CashRegister.create!(
          user: user,
          business: business,
          status: :open,
          opening_amount: 100.00,
          opened_at: Time.current
        )

        described_class.record_movement!(
          register: register,
          movement_type: :income,
          category: :cash_drop,
          amount: 50.00,
          reason: "Cash drop",
          actor: user
        )

        result = described_class.close!(register: register, actual_closing_amount: 140.00, actor: user)

        expect(result).to eq(register)
        expect(register.reload.status).to eq("closed")
        expect(register.actual_closing_amount).to eq(140.00)
        expect(register.expected_closing_amount).to eq(150.00)
        expect(register.drift).to eq(-10.00)
        expect(register.reconciled).to be_falsey
      end
    end

    it "marks the register as reconciled when actual equals expected" do
      Tenancy.with_business(business) do
        register = CashRegister.create!(
          user: user,
          business: business,
          status: :open,
          opening_amount: 100.00,
          opened_at: Time.current
        )

        described_class.close!(register: register, actual_closing_amount: 100.00, actor: user)

        expect(register.reload.status).to eq("closed")
        expect(register.expected_closing_amount).to eq(100.00)
        expect(register.drift).to eq(0.00)
        expect(register.reconciled).to be_truthy
      end
    end
  end
end
