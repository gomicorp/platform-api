module ExternalChannel
  class SendoAdapter < ExternalChannelAdapter
    {

    }
    attr_reader :base_url

    def initialize
      @base_url = "https://open.sendo.vn"
    end

    public

    # == 적절하게 정제된 데이터를 리턴합니다.
    def products(query_hash = {})
      refine_products(call_products(query_hash))
    end

    def orders(query_hash = {})
      refine_orders(call_orders(query_hash))
    end

    protected

    def login
      api_key = Rails.application.credentials.dig(:sendo, :api,  :key)
      api_password = Rails.application.credentials.dig(:sendo, :api, :password)
      login_url = URI("#{base_url}/login")
      login_body = {shop_key: api_key, secret_key: api_password}
      login_header = {'Content-Type': 'application/json'}
      response = req_post_json(login_url, login_body, login_header)
      data = JSON.parse response.body
      # 새로 발급받은 토큰만 유효하므로 기존 토큰을 대체함.
      @@token = data["result"]["token"]
    end

    # == 외부 채널의 API 를 사용하여 각 레코드를 가져옵니다.
    def call_products(query_hash = {})
      products_url = URI(url_with_query_hash("#{base_url}/api/partner/product/search", query_hash))
      call_all_post(products_url) do |data|
        data["result"]["data"].pluck("id")
      end
    end

    def call_orders(query); end

    # == call_XXX 로 가져온 레코드를 정제합니다.
    def refine_products(records); end
    def refine_orders(records); end

    # == json으로 Post요청을 날립니다.
    def req_post_json(url, body={}, headers={})
      request = Net::HTTP::Post.new(url)
      request.body = body.to_json

      headers.each_pair do |key, value|
        request[key] = value
      end

      http = Net::HTTP.new(url.host, url.port).tap do |o|
        o.use_ssl = true
      end
      http.request(request)
    end

    # == json으로 Get요청을 날립니다.
    def req_get_json(url, body={}, headers={})
      request = Net::HTTP::Get.new(url)
      request.body = body.to_json

      headers.each_pair do |key, value|
        request[key] = value
      end

      http = Net::HTTP.new(url.host, url.port).tap do |o|
        o.use_ssl = true
      end
      http.request(request)
    end

    private

    # == list 에서 모든 데이터를 요청합니다.
    def call_all_post(url)
      next_token = ""
      data = []
      while next_token.nil? == false
        each_data = call_each(url, next_token)
        next_token = each_data["result"]["next_token"]
        ap next_token
        data << if block_given?
                  yield each_data
                else
                  each_data
                end
      end
      data.flatten
    end

    # == 하나의 post요청 혹은 원하는 요청을 보냅니다.
    def call_each(url, next_token)
      body = {token: next_token, page_size: 50}
      header = {
        'Content-Type': 'application/json',
        'Authorization': "Bearer #{@@token}"
      }
      response = if block_given?
                   yield (url, body, header)
                 else
                   req_post_json(url, body, header)
                 end
      JSON.parse response.body
    end
  end
end