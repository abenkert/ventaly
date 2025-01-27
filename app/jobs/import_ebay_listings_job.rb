class ImportEbayListingsJob < ApplicationJob
  queue_as :default

  def perform(shop_id, last_sync_time = nil)
    shop = Shop.find(shop_id)
    ebay_account = shop.shopify_ebay_account
    return unless ebay_account

    # Track existing listings before import
    existing_item_ids = ebay_account.ebay_listings.pluck(:ebay_item_id)
    processed_item_ids = []

    token_service = EbayTokenService.new(shop)
    page = 1

    begin
      response = fetch_seller_listings(token_service.fetch_or_refresh_access_token, page, last_sync_time)
      namespaces = { 'ns' => 'urn:ebay:apis:eBLBaseComponents' }
      
      if response&.at_xpath('//ns:Ack', namespaces)&.text == 'Success'
        items = response.xpath('//ns:Item', namespaces)
        processed_item_ids += process_items(items, ebay_account)
        
        # Handle deletions - mark listings as ended if they no longer exist on eBay
        deleted_item_ids = existing_item_ids - processed_item_ids
        if deleted_item_ids.any?
          ebay_account.ebay_listings
                      .where(ebay_item_id: deleted_item_ids)
                      .update_all(
                        ebay_status: 'ended',
                        last_sync_at: Time.current
                      )
          
          Rails.logger.info "Marked #{deleted_item_ids.size} listings as ended"
        end

        ebay_account.update(last_listing_import_at: Time.current)
      end
    rescue => e
      Rails.logger.error("Error processing eBay listings: #{e.message}")
    end
  end

  private

  def process_items(items, ebay_account)
    processed_ids = []
    namespaces = { 'ns' => 'urn:ebay:apis:eBLBaseComponents' }
    
    items.each do |item|
      begin
        ebay_item_id = item.at_xpath('.//ns:ItemID', namespaces).text
        processed_ids << ebay_item_id
        
        listing = ebay_account.ebay_listings.find_or_initialize_by(ebay_item_id: ebay_item_id)

        # Update attributes regardless of whether it's a new or existing record
        listing.assign_attributes({
          title: item.at_xpath('.//ns:Title', namespaces)&.text,
          sale_price: item.at_xpath('.//ns:SellingStatus/ns:CurrentPrice', namespaces)&.text&.to_d,
          original_price: item.at_xpath('.//ns:StartPrice', namespaces)&.text&.to_d,
          quantity: item.at_xpath('.//ns:Quantity', namespaces)&.text&.to_i,
          shipping_profile_id: item.at_xpath('.//ns:SellerProfiles/ns:SellerShippingProfile/ns:ShippingProfileID', namespaces)&.text,
          location: item.at_xpath('.//ns:Location', namespaces)&.text,
          image_urls: extract_image_urls(item, namespaces),
          listing_format: item.at_xpath('.//ns:ListingType', namespaces)&.text,
          condition_id: item.at_xpath('.//ns:ConditionID', namespaces)&.text,
          condition_description: item.at_xpath('.//ns:ConditionDisplayName', namespaces)&.text,
          category_id: item.at_xpath('.//ns:PrimaryCategory/ns:CategoryID', namespaces)&.text,
          listing_duration: item.at_xpath('.//ns:ListingDuration', namespaces)&.text,
          end_time: Time.parse(item.at_xpath('.//ns:ListingDetails/ns:EndTime', namespaces)&.text.to_s),
          best_offer_enabled: item.at_xpath('.//ns:BestOfferDetails/ns:BestOfferEnabled', namespaces)&.text == 'true',
          ebay_status: item.at_xpath('.//ns:SellingStatus/ns:ListingStatus', namespaces)&.text&.downcase,
          last_sync_at: Time.current
        })

        if listing.changed?
          Rails.logger.info("Changes detected for #{ebay_item_id}: #{listing.changes.inspect}")
          if listing.save
            Rails.logger.info("#{listing.new_record? ? 'Created' : 'Updated'} listing #{ebay_item_id}")
            listing.cache_images unless listing.images.attached?
          else
            Rails.logger.error("Failed to save listing #{ebay_item_id}: #{listing.errors.full_messages.join(', ')}")
          end
        else
          Rails.logger.info("No changes detected for listing #{ebay_item_id}")
        end
      rescue => e
        Rails.logger.error("Error processing item: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))
      end
    end
    
    processed_ids
  end

  def extract_image_urls(item, namespaces)
    urls = []
    picture_details = item.at_xpath('.//ns:PictureDetails', namespaces)
    if picture_details
      urls << picture_details.at_xpath('.//ns:PictureURL', namespaces)&.text
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
          <EntriesPerPage>30</EntriesPerPage>
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
