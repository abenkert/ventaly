module Ebay
  class NotificationsController < ApplicationController
    skip_before_action :verify_authenticity_token, only: :create

    def create
      # TODO: Pending eBay notification integration
      # Current status: Endpoint configured but not receiving notifications from eBay
      # Next steps: 
      # 1. Verify eBay application notification settings
      # 2. Confirm endpoint is publicly accessible
      # 3. Add monitoring for incoming requests
      return head :unauthorized unless valid_ebay_notification?

      puts "Notification received"

      notification_data = params.permit!.to_h
    #   shop = Shop.find_by(shopify_domain: notification_data['Shop'])
      pp notification_data
      
      case notification_data['NotificationEventName']
      when 'AuctionCheckoutComplete'
        # FetchEbayOrdersJob.perform_later(shop.id)
        puts "AuctionCheckoutComplete notification received"
      end
      
      head :ok
    end

    private

    def valid_ebay_notification?
      # Implement eBay notification verification
      true
    end
  end
end 