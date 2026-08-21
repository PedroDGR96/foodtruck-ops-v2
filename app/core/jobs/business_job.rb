class BusinessJob < ApplicationJob
  def self.perform_later_for(business, *arguments)
    Current.set(business: business) { perform_later(*arguments) }
  end
end
