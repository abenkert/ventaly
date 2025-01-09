class ImportEbayListingsJob < ApplicationJob
  queue_as :default

  def perform(shop_id, last_sync_time = nil)
    shop = Shop.find(shop_id)
    ebay_account = shop.shopify_ebay_account
    return unless ebay_account

    token_service = EbayTokenService.new(shop)
    total_imported = 0
    page = 1

    response = fetch_ebay_listings(token_service.fetch_or_refresh_access_token, page, last_sync_time)
    
    # Create namespace for xpath queries
    namespaces = { 'ns' => 'urn:ebay:apis:eBLBaseComponents' }
    
    if response&.at_xpath('//ns:Ack', namespaces)&.text == 'Success'
      total_pages = 2  # Hardcoded for testing
      
      while page <= total_pages
        items = response.xpath('//ns:Item', namespaces)
        process_items(items, shop) if items.any?
        
        break if page >= total_pages  # Break before incrementing if we're on the last page
        
        page += 1
        response = fetch_ebay_listings(token_service.fetch_or_refresh_access_token, page, last_sync_time)
        break unless response&.at_xpath('//ns:Ack', namespaces)&.text == 'Success'
      end
      
      ebay_account.update(last_listing_import_at: Time.current)
      Rails.logger.info("Successfully imported/updated eBay listings. Total pages processed: #{page}")
    else
      error_message = response&.at_xpath('//ns:Errors/ns:LongMessage', namespaces)&.text
      Rails.logger.error("Failed to fetch eBay listings: #{error_message || 'Unknown error'}")
    end
  rescue StandardError => e
    Rails.logger.error("Error processing eBay listings: #{e.message}")
  end

  private

  def process_items(items, shop)
    namespaces = { 'ns' => 'urn:ebay:apis:eBLBaseComponents' }
    
    items.each do |item|
      ebay_item_id = item.at_xpath('.//ns:ItemID', namespaces)&.text
      
      listing = shop.shopify_ebay_account.ebay_listings.find_or_initialize_by(ebay_item_id: ebay_item_id)
      listing.assign_attributes(
        title: item.at_xpath('.//ns:Title', namespaces)&.text,
        description: item.at_xpath('.//ns:Description', namespaces)&.text,
        price: item.at_xpath('.//ns:BuyItNowPrice', namespaces)&.text&.to_d,
        quantity: item.at_xpath('.//ns:Quantity', namespaces)&.text&.to_i
      )
      
      listing.save if listing.changed?
    end
  end

  def fetch_ebay_listings(access_token, page_number, modified_after = nil)
    uri = URI('https://api.ebay.com/ws/api.dll')

    # This line belongs after detail level in the xml request
    # I am removing it for now because we want to import all listings and we need to be careful
    # about the modified date and dealing with job failures
    # also the order we recieve listings may be different?
    # #{modified_after ? "<ModTimeFrom>#{modified_after.iso8601}</ModTimeFrom>" : ""}
    
    xml_request = <<~XML
      <?xml version="1.0" encoding="utf-8"?>
      <GetMyeBaySellingRequest xmlns="urn:ebay:apis:eBLBaseComponents">
        <ActiveList>
          <Include>true</Include>
          <DetailLevel>ReturnAll</DetailLevel>
          <Pagination>
            <EntriesPerPage>1</EntriesPerPage>
            <PageNumber>#{page_number}</PageNumber>
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
      
      Nokogiri::XML(response.body)
    rescue StandardError => e
      Rails.logger.error("Error fetching eBay listings: #{e.message}")
      nil
    end
  end

  # def fetch_seller_listings(access_token, page_number, start_time_from = nil, start_time_to = nil)
  #   uri = URI('https://api.ebay.com/ws/api.dll')
    
  #   # If no time range is provided, default to last 120 days (eBay's maximum)
  #   start_time_from ||= 120.days.ago
  #   start_time_to ||= Time.current
    
  #   xml_request = <<~XML
  #     <?xml version="1.0" encoding="utf-8"?>
  #     <GetSellerListRequest xmlns="urn:ebay:apis:eBLBaseComponents">
  #       <DetailLevel>ReturnAll</DetailLevel>
  #       <StartTimeFrom>#{start_time_from.iso8601}</StartTimeFrom>
  #       <StartTimeTo>#{start_time_to.iso8601}</StartTimeTo>
  #       <IncludeDescription>true</IncludeDescription>
  #       <GranularityLevel>Fine</GranularityLevel>
  #       <Pagination>
  #         <EntriesPerPage>1</EntriesPerPage>
  #         <PageNumber>#{page_number}</PageNumber>
  #       </Pagination>
  #     </GetSellerListRequest>
  #   XML

  #   headers = {
  #     'X-EBAY-API-COMPATIBILITY-LEVEL' => '967',
  #     'X-EBAY-API-IAF-TOKEN' => access_token,
  #     'X-EBAY-API-DEV-NAME' => ENV['EBAY_DEV_ID'],
  #     'X-EBAY-API-APP-NAME' => ENV['EBAY_CLIENT_ID'],
  #     'X-EBAY-API-CERT-NAME' => ENV['EBAY_CLIENT_SECRET'],
  #     'X-EBAY-API-CALL-NAME' => 'GetSellerList',
  #     'X-EBAY-API-SITEID' => '0',
  #     'Content-Type' => 'text/xml'
  #   }

  #   begin
  #     response = Net::HTTP.post(uri, xml_request, headers)
  #     Rails.logger.info("Raw response: #{response.body}")
      
  #     Nokogiri::XML(response.body)
  #   rescue StandardError => e
  #     Rails.logger.error("Error fetching seller listings: #{e.message}")
  #     nil
  #   end
  # end
end
