# frozen_string_literal: true

require "rails_helper"

# Guards against untranslated UI: every static t("key") in views, helpers and
# mailers must resolve in pt-BR. Interpolated keys (t("orders.statuses.#{x}"))
# are verified down to their static prefix so a renamed/missing enum
# translation group still fails loudly here instead of leaking raw slugs into
# production screens.
RSpec.describe "I18n completeness", type: :view do
  SCANNED_DIRS = %w[app/views app/helpers app/mailers].freeze

  def translation_call_sites
    SCANNED_DIRS.flat_map do |dir|
      Dir[Rails.root.join(dir, "**/*.erb")] + Dir[Rails.root.join(dir, "**/*.rb")]
    end
  end

  it "resolves every static translation key in pt-BR" do
    missing = []

    translation_call_sites.each do |path|
      File.read(path).scan(/I18n\.t\(?[\s]*["']([^"']+)["']|[^a-zA-Z_.]t\([\s]*["']([^"']+)["']/)
           .flatten.compact.each do |key|
        next if key.blank?

        if key.include?("\#{")
          prefix = key.split(/\#\{/).first.chomp(".")
          missing << "#{path}: #{prefix}*" unless I18n.exists?(prefix, :"pt-BR")
        elsif !I18n.exists?(key, :"pt-BR")
          missing << "#{path}: #{key}"
        end
      end
    end

    expect(missing).to be_empty,
                       "unresolved pt-BR translation keys:\n  #{missing.uniq.sort.join("\n  ")}"
  end

  it "has no empty translations for order statuses and types" do
    %w[statuses order_types payment_statuses delivery_statuses kitchen_statuses].each do |group|
      translations = I18n.t("orders.#{group}", locale: :"pt-BR", default: {})
      expect(translations).to be_a(Hash), "orders.#{group} is not a translation hash"
      expect(translations.values).to all(be_present)
    end
  end
end
