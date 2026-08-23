# frozen_string_literal: true

require "rails_helper"

# CIS PostgreSQL Benchmark 6.x / OWASP transport protection: database traffic
# must be encrypted in transit. The db service enables SSL with a self-signed
# certificate (see compose.yml) and every runtime DATABASE_URL carries
# sslmode=require. This spec fails if either side regresses: the server flag
# or the encryption state of the very connection the app uses.
RSpec.describe "TLS transport", type: :model do
  def connection = ActiveRecord::Base.connection

  it "runs against a server with SSL enabled" do
    expect(connection.select_value("SHOW ssl")).to eq("on")
  end

  it "encrypts this very connection" do
    encrypted = connection.select_one(<<~SQL)
      SELECT ssl, version
      FROM pg_stat_ssl
      WHERE pid = pg_backend_pid()
    SQL
    expect(encrypted["ssl"]).to be(true)
    expect(encrypted["version"]).to match(/\ATLSv1\.[23]\z/)
  end

  it "keeps the configured connection URL requiring SSL" do
    url = ENV.fetch("DATABASE_URL")
    expect(url).to include("sslmode=require")
  end

  # Note: ssl_min_protocol_version is intentionally not asserted here - it is
  # a superuser-only setting and the runtime role must not be granted
  # pg_read_all_settings just for a test. It is pinned to TLSv1.2 in
  # compose.yml and checked at setup time.
end
