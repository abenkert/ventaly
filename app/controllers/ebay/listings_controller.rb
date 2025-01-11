module Ebay
  class ListingsController < Ebay::BaseController
    def index
      @listings = current_shop.shopify_ebay_account&.ebay_listings
                            &.includes(:kuralis_product)
                            &.order(created_at: :desc) || []
    end
  end
end 