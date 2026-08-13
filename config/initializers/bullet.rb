if defined?(Bullet)
  Bullet.enable = Rails.env.development? || Rails.env.test?
  Bullet.raise = Rails.env.test?
  Bullet.bullet_logger = true
  Bullet.rails_logger = true
  Bullet.add_safelist type: :n_plus_one_query, class_name: "IntegrationSetting", association: :business
  Bullet.add_safelist type: :unused_eager_loading, class_name: "IntegrationSetting", association: :business
  Bullet.add_safelist type: :counter_cache, class_name: "IntegrationSetting", association: :business
end
