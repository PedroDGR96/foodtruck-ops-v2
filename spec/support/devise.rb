RSpec.configure do |config|
  %i[request system].each do |spec_type|
    config.include Warden::Test::Helpers, type: spec_type
    config.before(:each, type: spec_type) { Warden.test_mode! }
    config.after(:each, type: spec_type) { Warden.test_reset! }
  end
end
