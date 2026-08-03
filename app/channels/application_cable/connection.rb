module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :business

    def connect
      self.business = Current.business || reject_unauthorized_connection
    end
  end
end
