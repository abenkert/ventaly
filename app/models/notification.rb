class Notification < ApplicationRecord
  belongs_to :shop
  
  validates :title, presence: true
  validates :message, presence: true
  validates :category, presence: true

  scope :unread, -> { where(read: false) }
  scope :by_category, ->(category) { where(category: category) }
end 