require 'rails_helper'

RSpec.describe Api::V1::ProductCollectionsController, type: :request do
  describe 'GET /api/v1/product_collections' do
    it 'works! (now write some real specs)' do
      get api_v1_product_collections_path
      expect(response).to have_http_status(200)
    end
  end
end
