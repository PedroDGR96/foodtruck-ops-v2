RSpec.configure do |config|
  config.include Warden::Test::Helpers, type: :request

  config.before(:each, type: :request) { Warden.test_mode! }
  config.after(:each, type: :request) { Warden.test_reset! }
end
