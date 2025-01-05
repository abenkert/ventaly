class ImportEbayListingsJob < ApplicationJob
  queue_as :default

  def perform(shop_id)
    shop = Shop.find(shop_id)
    ebay_account = shop.shopify_ebay_account

    return unless ebay_account

    # Example API call to fetch eBay listings
    response = fetch_ebay_listings(ebay_account.access_token)

    if response.success?
      listings = response.parsed_response['listings'] # Adjust based on actual API response structure

      listings.each do |listing|
        EbayListing.find_or_create_by(shop: shop, ebay_item_id: listing['item_id']) do |ebay_listing|
          ebay_listing.title = listing['title']
          ebay_listing.description = listing['description']
          ebay_listing.price = listing['price']
          ebay_listing.quantity = listing['quantity']
        end
      end
    else
      Rails.logger.error("Failed to fetch eBay listings: #{response.body}")
    end
  end

  private

  def fetch_ebay_listings(access_token)
    # Implement the API call to eBay to fetch listings
    # This is a placeholder for the actual API call
    HTTParty.get('https://api.ebay.com/some_endpoint', headers: { 'Authorization' => "Bearer #{access_token}" })
  end
end
