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

  class Scope
    attr_reader :user, :scope

    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      scope.all
    end
  end
end
