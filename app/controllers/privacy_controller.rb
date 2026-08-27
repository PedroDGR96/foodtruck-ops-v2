class PrivacyController < ApplicationController
  skip_after_action :verify_authorized
  layout "application"

  def show
    @business_name = Current.business&.name || "FoodTruckOps"
  end
end
