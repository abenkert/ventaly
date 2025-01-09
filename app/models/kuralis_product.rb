class KuralisProduct < ApplicationRecord
  belongs_to :shop
  belongs_to :shopify_product, optional: true
  belongs_to :ebay_listing, optional: true

  validates :title, presence: true
  validates :base_price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :base_quantity, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :status, presence: true

  # Scopes
  scope :active, -> { where(status: 'active') }
  scope :from_ebay, -> { where(source_platform: 'ebay') }
  scope :from_shopify, -> { where(source_platform: 'shopify') }
  scope :unlinked, -> { where(shopify_product_id: nil, ebay_listing_id: nil) }

  # Platform presence checks
  def listed_on_shopify?
    shopify_product.present?
  end

  def listed_on_ebay?
    ebay_listing.present?
  end

  def sync_needed?
    last_synced_at.nil? || last_synced_at < updated_at
  end
end 