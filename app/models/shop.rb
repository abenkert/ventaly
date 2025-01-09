# frozen_string_literal: true

class Shop < ApplicationRecord
  include ShopifyApp::ShopSessionStorageWithScopes

  has_one :shopify_ebay_account, dependent: :destroy
  has_many :kuralis_products, dependent: :destroy

  def api_version
    ShopifyApp.configuration.api_version
  end

  def notification_endpoint_url
    if Rails.env.production?
      "https://#{ENV['APP_HOST']}/ebay/notifications"
    else
      "https://#{ENV['DEV_APP_HOST']}/ebay/notifications"
    end
  end
end
