class FetchEbayOrdersJob < ApplicationJob
  queue_as :default

  def perform(shop_id)
    shop = Shop.find(shop_id)
    token = EbayTokenService.new(shop).fetch_or_refresh_access_token
    
    # Fetch recent active orders
    start_time = 24.hours.ago.iso8601
    
    uri = URI('https://api.ebay.com/ws/api.dll')
    
    xml_request = build_get_orders_request(token, start_time)
    
    headers = {
      'X-EBAY-API-COMPATIBILITY-LEVEL' => '967',
      'X-EBAY-API-IAF-TOKEN' => token,
      'X-EBAY-API-CALL-NAME' => 'GetOrders',
      'X-EBAY-API-SITEID' => '0',
      'Content-Type' => 'text/xml'
    }

    response = Net::HTTP.post(uri, xml_request, headers)
    # process_orders_response(response.body, shop) if response.is_a?(Net::HTTPSuccess)
    doc = Nokogiri::XML(response.body)
    pp doc  
  end

  private

  def build_get_orders_request(token, start_time)
    <<~XML
      <?xml version="1.0" encoding="utf-8"?>
      <GetOrdersRequest xmlns="urn:ebay:apis:eBLBaseComponents">
        <RequesterCredentials>
          <eBayAuthToken>#{token}</eBayAuthToken>
        </RequesterCredentials>
        <CreateTimeFrom>#{start_time}</CreateTimeFrom>
        <OrderRole>Seller</OrderRole>
        <OrderStatus>Active</OrderStatus>
        <ListingType>FixedPriceItem</ListingType>
        <DetailLevel>ReturnAll</DetailLevel>
        <Pagination>
          <EntriesPerPage>100</EntriesPerPage>
          <PageNumber>1</PageNumber>
        </Pagination>
        <Version>967</Version>
      </GetOrdersRequest>
    XML
  end

  def process_orders_response(response_xml)
    orders = response_xml.xpath('//xmlns:Order')
    
    orders.each do |order_xml|
      # Skip orders that don't have transactions
      next unless order_xml.at_xpath('.//xmlns:TransactionArray/xmlns:Transaction')
      
      order = create_or_update_order(order_xml)
      process_transactions(order, order_xml)
    end
  end

  def create_or_update_order(order_xml)
    order_id = order_xml.at_xpath('.//xmlns:OrderID')&.text
    ebay_status = order_xml.at_xpath('.//xmlns:OrderStatus')&.text
    
    order = Order.find_or_initialize_by(
      platform_order_id: order_id,
      shop_id: @shop.id
    )

    order.assign_attributes(
      status: map_ebay_status(ebay_status),
      total_price: order_xml.at_xpath('.//xmlns:Total')&.text&.to_d,
      subtotal_price: order_xml.at_xpath('.//xmlns:Subtotal')&.text&.to_d,
      shipping_price: order_xml.at_xpath('.//xmlns:ShippingServiceSelected/xmlns:ShippingServiceCost')&.text&.to_d,
      created_at: order_xml.at_xpath('.//xmlns:CreatedTime')&.text,
      platform_data: extract_platform_data(order_xml)
    )

    order.save!
    order
  end

  def process_transactions(order, order_xml)
    transactions = order_xml.xpath('.//xmlns:TransactionArray/xmlns:Transaction')
    
    transactions.each do |transaction|
      order_item = OrderItem.find_or_initialize_by(
        order_id: order.id,
        platform_order_item_id: transaction.at_xpath('.//xmlns:OrderLineItemID')&.text
      )

      order_item.assign_attributes(
        title: transaction.at_xpath('.//xmlns:Item/xmlns:Title')&.text,
        quantity: transaction.at_xpath('.//xmlns:QuantityPurchased')&.text&.to_i,
        unit_price: transaction.at_xpath('.//xmlns:TransactionPrice')&.text&.to_d,
        platform_item_id: transaction.at_xpath('.//xmlns:Item/xmlns:ItemID')&.text,
        platform_data: extract_transaction_data(transaction)
      )

      order_item.save!
    end
  end

  def map_ebay_status(ebay_status)
    case ebay_status
    when 'Active' then 'pending'
    when 'Completed' then 'completed'
    when 'Shipped' then 'shipped'
    else 'pending'
    end
  end

  def extract_platform_data(order_xml)
    {
      buyer_username: order_xml.at_xpath('.//xmlns:BuyerUserID')&.text,
      buyer_email: order_xml.at_xpath('.//xmlns:Buyer/xmlns:Email')&.text,
      buyer_first_name: order_xml.at_xpath('.//xmlns:Buyer/xmlns:UserFirstName')&.text,
      buyer_last_name: order_xml.at_xpath('.//xmlns:Buyer/xmlns:UserLastName')&.text,
      payment_status: order_xml.at_xpath('.//xmlns:CheckoutStatus/xmlns:Status')&.text,
      payment_method: order_xml.at_xpath('.//xmlns:CheckoutStatus/xmlns:PaymentMethod')&.text,
      shipping_service: order_xml.at_xpath('.//xmlns:ShippingServiceSelected/xmlns:ShippingService')&.text,
      shipping_address: {
        name: order_xml.at_xpath('.//xmlns:ShippingAddress/xmlns:Name')&.text,
        street1: order_xml.at_xpath('.//xmlns:ShippingAddress/xmlns:Street1')&.text,
        city: order_xml.at_xpath('.//xmlns:ShippingAddress/xmlns:CityName')&.text,
        state: order_xml.at_xpath('.//xmlns:ShippingAddress/xmlns:StateOrProvince')&.text,
        postal_code: order_xml.at_xpath('.//xmlns:ShippingAddress/xmlns:PostalCode')&.text,
        country: order_xml.at_xpath('.//xmlns:ShippingAddress/xmlns:CountryName')&.text,
        phone: order_xml.at_xpath('.//xmlns:ShippingAddress/xmlns:Phone')&.text
      }
    }
  end

  def extract_transaction_data(transaction)
    {
      transaction_id: transaction.at_xpath('.//xmlns:TransactionID')&.text,
      item_id: transaction.at_xpath('.//xmlns:Item/xmlns:ItemID')&.text,
      sales_record_number: transaction.at_xpath('.//xmlns:ShippingDetails/xmlns:SellingManagerSalesRecordNumber')&.text,
      created_date: transaction.at_xpath('.//xmlns:CreatedDate')&.text,
      invoice_sent_time: transaction.at_xpath('.//xmlns:InvoiceSentTime')&.text
    }
  end
end 