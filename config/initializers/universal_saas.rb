# Universal SaaS Core configuration for FoodTruck Ops
UniversalSaaS.configure do |config|
  config.tenant_class_name = "Business"
  config.tenant_id_column  = :business_id
  config.tenant_guc_name   = "app.business_id"
end