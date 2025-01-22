class MigrateEbayListingsJob < ApplicationJob
    ############################################################
    # This job is used to migrate eBay listings to KuralisProducts
    ############################################################
  queue_as :default

  def perform(shop_id, listing_ids)
    shop = Shop.find(shop_id)
    
    listing_ids.each do |listing_id|
      begin
        listing = shop.shopify_ebay_account.ebay_listings.find(listing_id)
        
        # Skip if already migrated
        next if listing.kuralis_product.present?
        
        # Create KuralisProduct from listing
        kuralis_product = shop.kuralis_products.create!(
          title: listing.title,
          description: listing.description,
          base_price: listing.sale_price,
          base_quantity: listing.quantity,
          sku: nil, # We'll need to generate this
          brand: listing.item_specifics["Brand"],
          condition: listing.condition_description,
          location: listing.location,
          images: listing.image_urls,
          product_attributes: listing.item_specifics,
          source_platform: 'ebay',
          status: listing.active? ? 'active' : 'inactive',
          ebay_listing: listing,
          last_synced_at: Time.current
        )

        Rails.logger.info "Successfully migrated eBay listing #{listing.ebay_item_id} to KuralisProduct #{kuralis_product.id}"
      rescue => e
        Rails.logger.error "Failed to migrate eBay listing #{listing_id}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
      end
    end
  end
end 