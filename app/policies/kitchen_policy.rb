# The kitchen display is a staff surface: every staff role can open the queue,
# but only kitchen staff and owners drive the cooking transitions (see
# OrderPolicy#start_cooking? and #mark_ready?).
class KitchenPolicy < ApplicationPolicy
  def show?
    staff?
  end
end
