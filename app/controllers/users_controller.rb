class UsersController < AuthenticatedController
  before_action :set_user, only: %i[edit update]

  def index
    authorize User
    @users = User.order(:role, :name)
  end

  def new
    @user = User.new
    authorize @user
  end

  def create
    @user = User.new(user_params)
    authorize @user

    if @user.save
      AuditLog.record!(action: "user_created", resource: "user", resource_id: @user.id, actor: current_user)
      redirect_to users_path, notice: t("users.created", name: @user.name)
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
    authorize @user
  end

  def update
    authorize @user

    if @user.update(user_params)
      AuditLog.record!(action: "user_updated", resource: "user", resource_id: @user.id, actor: current_user)
      redirect_to users_path, notice: t("users.updated", name: @user.name)
    else
      render :edit, status: :unprocessable_content
    end
  end

  def login
    redirect_to Devise::SessionsController.new(params[:id])
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:name, :email, :role, :password, :password_confirmation, :active)
  end
end
