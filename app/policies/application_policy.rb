class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  private

  def owner?
    user.owner?
  end

  def cashier?
    user.cashier?
  end

  def kitchen?
    user.kitchen?
  end

  def staff?
    owner? || cashier? || kitchen?
  end
end
