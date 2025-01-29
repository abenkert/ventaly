class MigrateEbayListingsJob < ApplicationJob
  ############################################################
  # This job is used to migrate eBay listings to KuralisProducts
  ############################################################
  queue_as :default

  def perform(shop_id, listing_ids)
    shop = Shop.find(shop_id)
    shopify_ebay_account = shop.shopify_ebay_account
    
    listing_ids.each do |listing_id|
      begin
        listing = shopify_ebay_account.ebay_listings.find(listing_id)
        
        # Skip if already migrated
        next if listing.kuralis_product.present?
        
        # Get weight from shipping profile mapping
        weight_oz = get_weight_from_shipping_profile(shopify_ebay_account, listing.shipping_profile_id)
        
        # Get tags from store category mapping
        tags = get_tags_from_store_category(shopify_ebay_account, listing.store_category_id)
        
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
          image_urls: listing.image_urls,
          images_last_synced_at: Time.current,
          product_attributes: listing.item_specifics,
          source_platform: 'ebay',
          status: listing.active? ? 'active' : 'inactive',
          ebay_listing: listing,
          last_synced_at: Time.current,
          weight_oz: weight_oz,
          tags: tags
        )

        # Cache images after creation
        kuralis_product.cache_images

        Rails.logger.info "Successfully migrated eBay listing #{listing.ebay_item_id} to KuralisProduct #{kuralis_product.id}"
      rescue => e
        Rails.logger.error "Failed to migrate eBay listing #{listing_id}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
      end
    end
  end

  private

  def get_weight_from_shipping_profile(shopify_ebay_account, shipping_profile_id)
    return nil if shipping_profile_id.blank?
    
    # Access weights directly from the eBay account
    weight_mapping = shopify_ebay_account.shipping_profile_weights[shipping_profile_id.to_s]
    weight_mapping.present? ? weight_mapping.to_d : nil
  end

  def get_tags_from_store_category(shopify_ebay_account, store_category_id)
    return [] if store_category_id.blank?
    
    # Access tags from category_tag_mappings on the eBay account
    tags_mapping = shopify_ebay_account.category_tag_mappings[store_category_id.to_s]
    tags_mapping.present? ? Array(tags_mapping) : []
  end
end 