class MenuController < AuthenticatedController
  def show
    authorize :menu, :show?
    raise ActionController::RoutingError.new("Business not found") unless Current.business
    @query = params[:query].to_s.strip
    @categories = MenuQuery.call(business: Current.business, query: @query || "")
  end
end
