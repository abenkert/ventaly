class EbayListing < ApplicationRecord
  belongs_to :shop

  validates :ebay_item_id, presence: true, uniqueness: { scope: :shop_id }
end 