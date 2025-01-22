class ShopifyProduct < ApplicationRecord
  belongs_to :shop
  has_one :kuralis_product
  has_many_attached :images

  validates :shop_id, presence: true
  validates :shopify_product_id, presence: true, uniqueness: { scope: :shop_id }
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

  def gid
    "gid://shopify/Product/#{shopify_product_id}"
  end

  def variant_gid
    "gid://shopify/ProductVariant/#{shopify_variant_id}"
  end

  def cache_images
    return if image_urls.blank?

    image_urls.each do |url|
      begin
        images.attach(io: URI.open(url), filename: File.basename(url))
      rescue => e
        Rails.logger.error "Failed to cache image from #{url}: #{e.message}"
      end
    end
    
    update(images_last_synced_at: Time.current)
  end
end 