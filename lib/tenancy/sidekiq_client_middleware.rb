module Tenancy
  class SidekiqClientMiddleware
    def call(_worker_class, job, _queue, _redis_pool)
      job["business_id"] ||= Current.business_id
      yield
    end
  end
end
