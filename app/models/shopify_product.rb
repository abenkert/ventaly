class ShopifyProduct < ApplicationRecord
  has_one :kuralis_product

  validates :shopify_product_id, presence: true, uniqueness: true
  validates :shopify_variant_id, presence: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :quantity, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :status, presence: true

  # Scopes
  scope :active, -> { where(status: 'active') }
  scope :published, -> { where(published: true) }

  # Helper methods
  def active?
    status == 'active'
  end

  def has_inventory?
    quantity.present? && quantity > 0
  end
end 