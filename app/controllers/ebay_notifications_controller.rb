class EbayNotificationsController < ApplicationController
  skip_before_action :verify_authenticity_token
  
  def create
    return head :unauthorized unless valid_ebay_notification?

    notification_data = params.permit!.to_h
    shop = Shop.find_by(shopify_domain: notification_data['Shop'])
    
    case notification_data['NotificationEventName']
    when 'AuctionCheckoutComplete'
      # Instead of processing notification data, queue a job to fetch orders
      FetchEbayOrdersJob.perform_later(shop.id)
    end
    
    head :ok
  end

  private

  def valid_ebay_notification?
    # Implement eBay notification verification
    true
  end
end 