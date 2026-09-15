# Drives the integration pollers on a fixed cadence. No-op for businesses still
# in mock mode, so the demo stack is unaffected. Re-enqueues itself so a single
# worker keeps the loop alive without an external scheduler.
class IntegrationPollScheduler < ApplicationJob
  INTERVAL = 5.minutes

  def perform
    PaymentStatusPoller.perform_later
    MarketplaceEventPoller.perform_later
    self.class.set(wait: INTERVAL).perform_later
  end
end
