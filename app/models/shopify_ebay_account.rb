class ShopifyEbayAccount < ApplicationRecord
  belongs_to :shop
  has_many :ebay_listings, dependent: :destroy

  validates :shop, presence: true
  validates :access_token, presence: true
end
