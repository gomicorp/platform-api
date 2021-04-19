# == Schema Information
#
# Table name: product_item_groups
#
#  id         :bigint           not null, primary key
#  deleted_at :datetime
#  name       :string(255)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  brand_id   :bigint           not null
#  country_id :bigint
#
# Indexes
#
#  index_product_item_groups_on_brand_id    (brand_id)
#  index_product_item_groups_on_country_id  (country_id)
#  index_product_item_groups_on_deleted_at  (deleted_at)
#
# Foreign Keys
#
#  fk_rails_...  (brand_id => brands.id)
#  fk_rails_...  (country_id => countries.id)
#
require 'test_helper'

class ProductItemGroupTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
