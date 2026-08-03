module Tenancy
  class SidekiqServerMiddleware
    def call(_worker, job, _queue)
      return yield unless job["business_id"]

      Tenancy.with_business(job.fetch("business_id")) { yield }
    end
  end
end
