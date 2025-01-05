class SettingsController < AuthenticatedController
  layout 'authenticated'

  def index
    shop = Shop.find_by(shopify_domain: current_shopify_domain)
    @ebay_account_linked = shop&.shopify_ebay_account.present?
  end
end
