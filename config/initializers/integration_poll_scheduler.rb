# Seeds the integration polling loop when a Sidekiq server boots. The
# scheduler re-enqueues itself, so a single worker keeps the cadence; the
# SET NX guard keeps a multi-worker fleet from seeding duplicates.
if defined?(Sidekiq) && Sidekiq.server?
  Sidekiq.configure_server do |config|
    config.on(:startup) do
      seeded = Sidekiq.redis { |c| c.set("integrations:scheduler:seed", "1", nx: true, ex: 86_400) }
      IntegrationPollScheduler.perform_later if seeded
    end
  end
end
