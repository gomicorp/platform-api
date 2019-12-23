# 이렇게 하면 Zohomap이 만들어진다.
# Zohomap.create(:zohoable => Adjustment.all[0], :zoho_id => "adadfdsf")

# 이렇게 하면 Adjustment가 반환된다.
# Zohomap.all[0].zohoable
class Adjustment < ApplicationRecord
  has_many :adjustment_product_items
  has_one :zohomap, as: :zohoable
end