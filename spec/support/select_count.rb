# Counts the SELECT queries issued while a block runs. Used to pin eager-loading
# behavior in request specs without shipping Bullet in the bundle.
module SelectCount
  def select_count(&block)
    count = 0
    ActiveSupport::Notifications.subscribed(
      ->(_name, _started, _finished, _id, payload) do
        count += 1 if payload[:sql].to_s.lstrip.match?(/\ASELECT/i)
      end,
      "sql.active_record"
    ) { block.call }
    count
  end
end

RSpec.configure do |config|
  config.include SelectCount, type: :request
end
