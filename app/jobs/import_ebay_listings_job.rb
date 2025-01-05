class ImportEbayListingsJob < ApplicationJob
  queue_as :default

  def perform(shop_id)
    shop = Shop.find(shop_id)
    ebay_account = shop.shopify_ebay_account

    return unless ebay_account

    response = fetch_ebay_listings(ebay_account.access_token)

    if response.success?
      listings = response.body[:get_my_ebay_selling_response][:active_list][:item_array][:item] || []

      listings.each do |listing|
        EbayListing.find_or_create_by(shop: shop, ebay_item_id: listing[:item_id]) do |ebay_listing|
          ebay_listing.title = listing[:title]
          ebay_listing.description = listing[:description]
          ebay_listing.price = listing[:selling_status][:current_price][:value]
          ebay_listing.quantity = listing[:quantity]
        end
      end
    else
      Rails.logger.error("Failed to fetch eBay listings: #{response.body}")
    end
  end

  private

  def fetch_ebay_listings(access_token)
    client = Savon.client(
      wsdl: 'https://developer.ebay.com/webservices/latest/ebaySvc.wsdl',
      endpoint: 'https://api.ebay.com/ws/api.dll',
      namespaces: { 'xmlns' => 'urn:ebay:apis:eBLBaseComponents' },
      headers: {
        'X-EBAY-API-COMPATIBILITY-LEVEL' => '967',
        'X-EBAY-API-DEV-NAME' => ENV['EBAY_DEV_ID'],
        'X-EBAY-API-APP-NAME' => ENV['EBAY_APP_ID'],
        'X-EBAY-API-CERT-NAME' => ENV['EBAY_CERT_ID'],
        'X-EBAY-API-CALL-NAME' => 'GetMyeBaySelling',
        'X-EBAY-API-SITEID' => '0'
      }
    )

    message = {
      'RequesterCredentials' => { 'eBayAuthToken' => access_token },
      'ActiveList' => { 'Include' => true }
    }

    client.call(:get_my_ebay_selling, message: message)
  end
end
