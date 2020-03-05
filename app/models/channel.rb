class Channel < ApplicationRecord
  has_many :order_infos
  has_many :product_options

  validates :name, uniqueness: true
end
