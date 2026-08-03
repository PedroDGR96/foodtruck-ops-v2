if defined?(Bullet)
  Bullet.enable = Rails.env.development? || Rails.env.test?
  Bullet.raise = Rails.env.test?
  Bullet.bullet_logger = true
  Bullet.rails_logger = true
end
