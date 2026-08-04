class AuthenticatedController < ApplicationController
  layout "authenticated"

  before_action :authenticate_user!
end
