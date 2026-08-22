class CustomersController < AuthenticatedController
  before_action :set_customer, only: %i[show edit update destroy]

  def index
    authorize Customer
    @customers = Current.business.customers.ordered
    @customers = @customers.search(params[:query]) if params[:query].present?
    @customer_stats = {}
    @customers.each do |customer|
      history = CustomerHistory.call(customer)
      @customer_stats[customer.id] = { order_count: history.order_count, total_spent: history.total_spent }
    end
  end

  def show
    authorize @customer
    @history = CustomerHistory.call(@customer)
  end

  def new
    authorize Customer
    @customer = Customer.new
  end

  def create
    authorize Customer
    @customer = Customer.new(customer_params)

    if @customer.save
      redirect_to customer_path(@customer), notice: t("customers.created", name: @customer.name)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @customer
  end

  def update
    authorize @customer

    if @customer.update(customer_params)
      redirect_to customer_path(@customer), notice: t("customers.updated", name: @customer.name)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @customer
    @customer.discard!

    redirect_to customers_path, notice: t("customers.discarded", name: @customer.name)
  end

  private

  def set_customer
    @customer = Current.business.customers.find(params[:id])
  end

  def customer_params
    params.require(:customer).permit(:name, :phone, :whatsapp, :birthday, :notes)
  end
end
