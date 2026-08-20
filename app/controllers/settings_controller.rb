class SettingsController < AuthenticatedController
  def edit
    @business = Current.business
    authorize @business
  end

  def update
    @business = Current.business
    authorize @business

    if @business.update(business_params)
      AuditLog.record!(
        action: "settings_updated",
        resource: "business",
        resource_id: @business.id,
        actor: current_user,
        metadata: business_params.to_h
      )
      redirect_to edit_settings_path, notice: t("settings.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def business_params
    params.require(:business).permit(:name, :timezone, :currency, :active, :delivery_fee)
  end
end
