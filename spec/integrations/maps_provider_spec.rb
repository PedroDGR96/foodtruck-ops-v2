require "rails_helper"

RSpec.describe MapsProvider do
  it { expect { described_class.geocode(settings: {}, args: {}) }.to raise_error(NotImplementedError) }
  it { expect { described_class.distance(settings: {}, args: {}) }.to raise_error(NotImplementedError) }
end
