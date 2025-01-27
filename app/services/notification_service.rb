class NotificationService
  def self.create(shop:, title:, message:, category:, metadata: {}, failed_product_ids: [], successful_product_ids: [])
    Notification.create!(
      shop: shop,
      title: title,
      message: message,
      category: category,
      metadata: metadata,
      failed_product_ids: failed_product_ids,
      successful_product_ids: successful_product_ids,
      read: false
    )
  end
end 