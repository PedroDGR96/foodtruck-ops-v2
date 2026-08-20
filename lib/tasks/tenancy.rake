namespace :tenancy do
  desc "Open an interactive console bound to a business"
  task :console, [ :business_id ] => :environment do |_task, arguments|
    business = Business.find(arguments.fetch(:business_id))
    Tenancy.with_business(business) { binding.irb }
  end
end
