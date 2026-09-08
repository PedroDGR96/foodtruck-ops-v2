class Business < ApplicationRecord
  has_many :users, dependent: :restrict_with_exception
  has_many :categories, dependent: :restrict_with_exception
  has_many :products, dependent: :restrict_with_exception
  has_many :product_variants, through: :products
  has_many :product_addon_groups, through: :products
  has_many :product_addons, through: :product_addon_groups
  has_many :orders, dependent: :restrict_with_exception
  has_many :payments, through: :orders
  has_many :customers, dependent: :restrict_with_exception
  has_many :cash_registers, dependent: :restrict_with_exception
  has_many :cash_movements, dependent: :restrict_with_exception
  has_many :integration_settings, dependent: :restrict_with_exception

  has_many :delivery_addresses, dependent: :restrict_with_exception
  has_many :deliveries, dependent: :restrict_with_exception

  has_many :consent_records, dependent: :restrict_with_exception
  has_many :data_subject_requests, dependent: :restrict_with_exception
  has_many :privacy_incidents, dependent: :restrict_with_exception

  # Runtime switch between deterministic sandbox adapters (mock, default) and
  # real provider adapters (live). Adapters are selected per provider through
  # AdapterResolver; live keeps mocks as fallback until a real adapter exists.
  ADAPTER_MODES = %w[mock live].freeze

  enum :integration_adapter_mode, ADAPTER_MODES.index_with(&:itself)

  validates :name, :currency, :timezone, presence: true
  validates :delivery_fee, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :integration_adapter_mode, inclusion: { in: ADAPTER_MODES }
end
