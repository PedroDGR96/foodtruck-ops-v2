class HomeController < AuthenticatedController
  def index
    authorize :home, :index?
  end
end
