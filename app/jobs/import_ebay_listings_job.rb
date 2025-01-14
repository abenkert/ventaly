class ImportEbayListingsJob < ApplicationJob
  queue_as :default

  def perform(shop_id, last_sync_time = nil)
    shop = Shop.find(shop_id)
    ebay_account = shop.shopify_ebay_account
    return unless ebay_account

    token_service = EbayTokenService.new(shop)
    page = 1

    begin
      response = fetch_seller_listings(token_service.fetch_or_refresh_access_token, page, last_sync_time)
      namespaces = { 'ns' => 'urn:ebay:apis:eBLBaseComponents' }
      
      if response&.at_xpath('//ns:Ack', namespaces)&.text == 'Success'
        items = response.xpath('//ns:Item', namespaces)
        process_items(items, ebay_account)
        
        ebay_account.update(last_listing_import_at: Time.current)
      end
    rescue => e
      Rails.logger.error("Error processing eBay listings: #{e.message}")
    end
  end

  private

  def process_items(items, ebay_account)
    items.each do |item|
      begin
        listing = ebay_account.ebay_listings.find_or_initialize_by(
          ebay_item_id: item.at_xpath('.//ItemID').text
        )

        listing.assign_attributes({
          title: item.at_xpath('.//Title')&.text,
          description: item.at_xpath('.//Description')&.text,
          sale_price: item.at_xpath('.//SellingStatus/CurrentPrice')&.text&.to_d,
          original_price: item.at_xpath('.//StartPrice')&.text&.to_d,
          quantity: item.at_xpath('.//Quantity')&.text&.to_i,
          shipping_profile_id: item.at_xpath('.//SellerProfiles/SellerShippingProfile/ShippingProfileID')&.text,
          location: item.at_xpath('.//Location')&.text,
          image_urls: extract_image_urls(item),
          listing_format: item.at_xpath('.//ListingType')&.text,
          condition_id: item.at_xpath('.//ConditionID')&.text,
          condition_description: item.at_xpath('.//ConditionDisplayName')&.text,
          category_id: item.at_xpath('.//PrimaryCategory/CategoryID')&.text,
          listing_duration: item.at_xpath('.//ListingDuration')&.text,
          end_time: Time.parse(item.at_xpath('.//ListingDetails/EndTime')&.text),
          best_offer_enabled: item.at_xpath('.//BestOfferDetails/BestOfferEnabled')&.text == 'true',
          ebay_status: item.at_xpath('.//SellingStatus/ListingStatus')&.text&.downcase,
          last_sync_at: Time.current
        })

        if listing.save
          listing.cache_images
        else
          Rails.logger.error("Failed to save listing #{listing.ebay_item_id}: #{listing.errors.full_messages.join(', ')}")
        end
      rescue => e
        Rails.logger.error("Error processing item #{item.at_xpath('.//ItemID')&.text}: #{e.message}")
      end
    end
  end

  def extract_image_urls(item)
    urls = []
    picture_details = item.at_xpath('.//PictureDetails')
    if picture_details
      urls << picture_details.at_xpath('.//PictureURL')&.text
    end
    urls.compact
  end

  def fetch_seller_listings(access_token, page_number, start_time_from = nil, start_time_to = nil)
    uri = URI('https://api.ebay.com/ws/api.dll')
    
    # If no time range is provided, default to last 120 days (eBay's maximum)
    start_time_from ||= 120.days.ago
    start_time_to ||= Time.current
    
    xml_request = <<~XML
      <?xml version="1.0" encoding="utf-8"?>
      <GetSellerListRequest xmlns="urn:ebay:apis:eBLBaseComponents">
        <DetailLevel>ReturnAll</DetailLevel>
        <StartTimeFrom>#{start_time_from.iso8601}</StartTimeFrom>
        <StartTimeTo>#{start_time_to.iso8601}</StartTimeTo>
        <IncludeDescription>true</IncludeDescription>
        <GranularityLevel>Fine</GranularityLevel>
        <Pagination>
          <EntriesPerPage>2</EntriesPerPage>
          <PageNumber>#{page_number}</PageNumber>
        </Pagination>
      </GetSellerListRequest>
    XML

    headers = {
      'X-EBAY-API-COMPATIBILITY-LEVEL' => '967',
      'X-EBAY-API-IAF-TOKEN' => access_token,
      'X-EBAY-API-DEV-NAME' => ENV['EBAY_DEV_ID'],
      'X-EBAY-API-APP-NAME' => ENV['EBAY_CLIENT_ID'],
      'X-EBAY-API-CERT-NAME' => ENV['EBAY_CLIENT_SECRET'],
      'X-EBAY-API-CALL-NAME' => 'GetSellerList',
      'X-EBAY-API-SITEID' => '0',
      'Content-Type' => 'text/xml'
    }

    begin
      response = Net::HTTP.post(uri, xml_request, headers)
      Rails.logger.info("Raw response: #{response.body}")
      
      Nokogiri::XML(response.body)
    rescue StandardError => e
      Rails.logger.error("Error fetching seller listings: #{e.message}")
      nil
    end
  end

    # def fetch_ebay_listings(access_token, page_number, modified_after = nil)
  #   uri = URI('https://api.ebay.com/ws/api.dll')

  #   # This line belongs after detail level in the xml request
  #   # I am removing it for now because we want to import all listings and we need to be careful
  #   # about the modified date and dealing with job failures
  #   # also the order we recieve listings may be different?
  #   # #{modified_after ? "<ModTimeFrom>#{modified_after.iso8601}</ModTimeFrom>" : ""}
    
  #   xml_request = <<~XML
  #     <?xml version="1.0" encoding="utf-8"?>
  #     <GetMyeBaySellingRequest xmlns="urn:ebay:apis:eBLBaseComponents">
  #       <ActiveList>
  #         <Include>true</Include>
  #         <DetailLevel>ReturnAll</DetailLevel>
  #         <Pagination>
  #           <EntriesPerPage>1</EntriesPerPage>
  #           <PageNumber>#{page_number}</PageNumber>
  #         </Pagination>
  #       </ActiveList>
  #     </GetMyeBaySellingRequest>
  #   XML

  #   headers = {
  #     'X-EBAY-API-COMPATIBILITY-LEVEL' => '967',
  #     'X-EBAY-API-IAF-TOKEN' => access_token,
  #     'X-EBAY-API-DEV-NAME' => ENV['EBAY_DEV_ID'],
  #     'X-EBAY-API-APP-NAME' => ENV['EBAY_CLIENT_ID'],
  #     'X-EBAY-API-CERT-NAME' => ENV['EBAY_CLIENT_SECRET'],
  #     'X-EBAY-API-CALL-NAME' => 'GetMyeBaySelling',
  #     'X-EBAY-API-SITEID' => '0',
  #     'Content-Type' => 'text/xml'
  #   }

  #   begin
  #     response = Net::HTTP.post(uri, xml_request, headers)
  #     Rails.logger.info("Raw response: #{response.body}")
      
  #     Nokogiri::XML(response.body)
  #   rescue StandardError => e
  #     Rails.logger.error("Error fetching eBay listings: #{e.message}")
  #     nil
  #   end
  # end
end
