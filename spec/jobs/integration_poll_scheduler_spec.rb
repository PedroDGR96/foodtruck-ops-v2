require "rails_helper"

RSpec.describe IntegrationPollScheduler do
  it "runs both pollers and re-enqueues itself with the cadence" do
    ActiveJob::Base.queue_adapter = :test

    described_class.perform_now

    jobs = ActiveJob::Base.queue_adapter.enqueued_jobs
    expect(jobs.map { |j| j[:job] }).to include(PaymentStatusPoller, MarketplaceEventPoller)

    scheduler = jobs.find { |j| j[:job] == IntegrationPollScheduler && j[:at].present? }
    expect(scheduler).to be_present
    expect(scheduler[:at]).to be_within(2).of((Time.now + described_class::INTERVAL).to_i)
  ensure
    ActiveJob::Base.queue_adapter = :sidekiq
  end
end
