# frozen_string_literal: true

require "rails_helper"

# CIS PostgreSQL Benchmark: "Ensure public schema privileges are revoked
# from the PUBLIC role". PUBLIC is every role, including any future role
# someone creates carelessly; keeping it empty means privileges only exist
# where db-prepare / bootstrap explicitly granted them.
RSpec.describe "Public schema privilege posture", type: :model do
  def connection = ActiveRecord::Base.connection

  def privileged?(role, privilege)
    # Role and privilege names are test-local constants, not user input.
    connection.select_value(
      "SELECT has_schema_privilege('#{role}', 'public', '#{privilege}')"
    )
  end

  it "grants the PUBLIC role nothing on the public schema" do
    expect(privileged?("public", "CREATE")).to be(false)
  end

  it "lets the runtime role traverse but never create" do
    expect(privileged?("app", "USAGE")).to be(true)
    expect(privileged?("app", "CREATE")).to be(false)
  end

  it "keeps object-creation rights on the migration role" do
    expect(privileged?("migrator", "USAGE")).to be(true)
    expect(privileged?("migrator", "CREATE")).to be(true)
  end
end
