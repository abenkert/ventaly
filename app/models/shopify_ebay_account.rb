class ShopifyEbayAccount < ApplicationRecord
  belongs_to :shop

  validates :shop, presence: true
  validates :access_token, presence: true
end
