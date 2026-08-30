class DataSubjectRequestsController < AuthenticatedController
  before_action :set_dsar, only: %i[show update]

  def index
    authorize DataSubjectRequest
    @dsars = policy_scope(DataSubjectRequest).order(created_at: :desc)
  end

  def new
    @dsar = DataSubjectRequest.new
    authorize @dsar
  end

  def show
    authorize @dsar
  end

  def create
    @dsar = Current.business.data_subject_requests.build(dsar_params)
    @dsar.user = current_user if current_user
    @dsar.ip_address = request.remote_ip
    @dsar.user_agent = request.user_agent
    authorize @dsar

    if @dsar.save
      redirect_to data_subject_requests_path, notice: t("compliance.dsar.created")
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize @dsar

    new_status = dsar_params[:status]
    if new_status == "completed" && @dsar.status != "completed"
      @dsar.completed_at = Time.current
    end

    if @dsar.update(dsar_params)
      redirect_to @dsar, notice: t("compliance.dsar.updated")
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def set_dsar
    @dsar = Current.business.data_subject_requests.find(params[:id])
  end

  def dsar_params
    params.require(:data_subject_request).permit(:data_subject_email, :request_type, :description, :status, :response_notes)
  end
end
