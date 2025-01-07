class ImportEbayListingsJob < ApplicationJob
  queue_as :default

  def perform(shop_id)
    shop = Shop.find(shop_id)
    ebay_account = shop.shopify_ebay_account

    return unless ebay_account
    token_service = EbayTokenService.new(shop)

    response = fetch_ebay_listings(token_service.fetch_or_refresh_access_token)

    # if response.success?
    #   # listings = response.body[:get_my_ebay_selling_response][:active_list][:item_array][:item] || []

    #   # listings.each do |listing|
    #   #   EbayListing.find_or_create_by(shop: shop, ebay_item_id: listing[:item_id]) do |ebay_listing|
    #   #     ebay_listing.title = listing[:title]
    #   #     ebay_listing.description = listing[:description]
    #   #     ebay_listing.price = listing[:selling_status][:current_price][:value]
    #   #     ebay_listing.quantity = listing[:quantity]
    #   #   end
    #   # end
    #   pp response
    # else
    #   Rails.logger.error("Failed to fetch eBay listings: #{response.body}")
    # end
  end

  private

  def fetch_ebay_listings(access_token)
    uri = URI('https://api.ebay.com/ws/api.dll')
    
    xml_request = <<~XML
      <?xml version="1.0" encoding="utf-8"?>
      <GetMyeBaySellingRequest xmlns="urn:ebay:apis:eBLBaseComponents">
        <ActiveList>
          <Include>true</Include>
          <DetailLevel>ReturnAll</DetailLevel>
          <Pagination>
            <EntriesPerPage>1</EntriesPerPage>
            <PageNumber>1</PageNumber>
          </Pagination>
        </ActiveList>
      </GetMyeBaySellingRequest>
    XML
  
    headers = {
      'X-EBAY-API-COMPATIBILITY-LEVEL' => '967',
      'X-EBAY-API-IAF-TOKEN' => access_token,
      'X-EBAY-API-DEV-NAME' => ENV['EBAY_DEV_ID'],
      'X-EBAY-API-APP-NAME' => ENV['EBAY_CLIENT_ID'],
      'X-EBAY-API-CERT-NAME' => ENV['EBAY_CLIENT_SECRET'],
      'X-EBAY-API-CALL-NAME' => 'GetMyeBaySelling',
      'X-EBAY-API-SITEID' => '0',
      'Content-Type' => 'text/xml'
    }
  
    begin
      response = Net::HTTP.post(uri, xml_request, headers)
      Rails.logger.info("Raw response: #{response.body}")
      
      if response.is_a?(Net::HTTPSuccess)
        doc = Nokogiri::XML(response.body)
        # Parse the response here
        pp doc
      else
        Rails.logger.error("Failed to fetch eBay listings: #{response.body}")
        nil
      end
    rescue StandardError => e
      Rails.logger.error("Error fetching eBay listings: #{e.message}")
      nil
    end
  end
end
