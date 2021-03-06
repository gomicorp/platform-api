module Brands
  class DefaultDecorator < BrandDecorator
    data_keys_from_model :brand
    data_key :name do |record|
      record.translate.name
    end
  end
end
