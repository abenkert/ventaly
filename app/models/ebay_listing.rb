class EbayListing < ApplicationRecord
  belongs_to :shopify_ebay_account

  validates :ebay_item_id, presence: true, uniqueness: { scope: :shopify_ebay_account_id }
end 