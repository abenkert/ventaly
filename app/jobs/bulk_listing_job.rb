class BulkListingJob < ApplicationJob
  queue_as :default

  def perform(shop_id:, product_ids:, platform:)
    shop = Shop.find(shop_id)
    products = shop.kuralis_products.where(id: product_ids)
    
    successful_ids = []
    failed_ids = []
    failed_details = []

    products.find_each do |product|
      begin
        case platform
        when 'shopify'
            next if product.shopify_product.present?
            Shopify::CreateListingJob.perform_now(product.id)
            successful_ids << product.id
        when 'ebay'
        # TODO: Implement eBay listing creation
        #   next if product.ebay_listing.present?
        #   CreateEbayListingJob.perform_now(
        #     shop_id: shop.id,
        #     kuralis_product_id: product.id
        #   )
        #   successful_ids << product.id
        end
      rescue => e
        failed_ids << product.id
        failed_details << {
          id: product.id,
          title: product.title,
          error: e.message
        }
        Rails.logger.error("Failed to create #{platform} listing for product #{product.id}: #{e.message}")
      end
    end

    # Send notification about completion
    NotificationService.create(
      shop: shop,
      title: "Bulk Listing Complete",
      message: generate_completion_message(
        platform: platform,
        success_count: successful_ids.size,
        failed_details: failed_details
      ),
      category: 'bulk_listing',
      metadata: {
        platform: platform,
        total_processed: product_ids.size,
        error_details: failed_details
      },
      failed_product_ids: failed_ids,
      successful_product_ids: successful_ids
    )
  end

  private

  def generate_completion_message(platform:, success_count:, failed_details:)
    message = "Bulk listing to #{platform.titleize} completed:\n"
    message += "✓ Successfully listed: #{success_count}\n"
    
    if failed_details.any?
      message += "✗ Failed to list: #{failed_details.size}\n\n"
      message += "Failed products:\n"
      failed_details.each do |product|
        message += "- #{product[:title]} (ID: #{product[:id]}): #{product[:error]}\n"
      end
    end

    message
  end
end 