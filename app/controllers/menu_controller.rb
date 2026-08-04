class MenuController < AuthenticatedController
  def show
    authorize :menu, :show?
    @query = params[:query].to_s.strip
    @categories = MenuQuery.call(business: Current.business, query: @query)
  end
end
