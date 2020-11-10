module ExternalChannel
  class SendoAdapter < BaseAdapter
    # Product 요청 파라미터
    # {
    #   date_form: yyyy/mm/dd string,
    #   date_to: yyyy/mm/dd string,
    #   product_name: string,
    # }
    #
    # Order 요청 파라미터
    # {
    #   order_date_from: yyyy/mm/dd string
    #   order_date_to: yyyy/mm/dd string
    #   order_status_date_from: yyyy/mm/dd string (주문 변경 일자)
    #   order_status_date_to: yyyy/mm/dd string (주문 변경 일자)
    #   order_status: 주문 상태
    # }

    attr_reader :base_url, :default_headers, :token

    def initialize
      @base_url = "https://open.sendo.vn"
      @token = ExternalChannelToken.find_or_create_by(country: Country.vn,
                                                      channel: Channel.find_by(name: 'Sendo'))

      @default_headers = {
        'Content-Type': 'application/json'
      }
    end

    def check_token_validation
      if !token.auth_token || @token.auth_token_expired?
        login
      end
    end

    public

    # == 적절하게 정제된 데이터를 리턴합니다.
    @override
    def products(query_hash = {})
      check_token_validation

      refine_products(call_products(query_hash))
    end

    @override
    def orders(query_hash = {})
      check_token_validation

      refine_orders(call_orders(query_hash))
    end

    @override
    def login
      api_key = Rails.application.credentials.dig(:sendo, :api,  :key)
      api_password = Rails.application.credentials.dig(:sendo, :api, :password)
      login_url = URI("#{base_url}/login")
      login_body = {shop_key: api_key, secret_key: api_password}

      data = request_post(login_url, login_body, default_headers)

      token.update(auth_token: data['result']['token'],
                   auth_token_expire_time: data['result']['expires'].to_datetime)
    end

    # == 외부 채널의 API 를 사용하여 각 레코드를 가져옵니다.
    @override
    def call_products(query_hash = {})
      products_url = URI("#{base_url}/api/partner/product/search")
      products_body = {
        token: '',
        page_size: 50
      }.merge(query_hash)
      products_header = {
        'Authorization': "bearer #{token.auth_token}",
        'Content-Type': 'application/json',
      }
      product_ids = request_lists(products_url, products_body, products_header) do |products|
        products["result"]["data"].pluck("id")
      end
      get_all_by_ids(product_ids, "#{base_url}/api/partner/product")
    end

    @override
    def call_orders(query_hash = {})
      orders_url = URI("#{base_url}/api/partner/salesorder/search")
      orders_body = {
        token: ''
      }.merge(query_hash)
      orders_header = {
        'Authorization': "bearer #{token.auth_token}",
        'Content-Type': 'application/json',
        'cache-control': 'no-cache'
      }
      request_lists(orders_url, orders_body, orders_header) do |orders|
        orders["result"]["data"]
      end
    end

    # == call_XXX 로 가져온 레코드를 정제합니다.
    @override
    def refine_products(products)
      products.map do |product|
        {
          id: product["id"],
          title: product["name"],
          channel_name: 'sendo',
          brand_name: product["brand_name"] || 'not brand',
          variants: form_variants(product)
        }
      end
    end

    @override
    def refine_orders(orders)
      orders.map do |order|
        sales_data = order["sales_order"]
        sales_details = order["sku_details"]
        {
          id: sales_data["order_number"],
          order_number: sales_data["order_number"],
          billing_amount: sales_data["total_amount_buyer"],
          variants_ids: sales_details.map {|option| [option["product_variant_id"], option["quantity"]]},
          order_status: map_order_status(sales_data["order_status"]),
          cancel_status: cancelled_status(sales_data["order_status"]),
          shipping_status: shipping_status(sales_data["order_status"]),
          pay_method: map_pay_method(sales_data["payment_method"])
        }
      end
    end

    private

    ### === 데이터를 불러오는 로직입니다.

    def get_all_by_ids(ids, url, query_hash = {})
      header = {
          'Content-Type': 'application/json',
          'Authorization': "Bearer #{token.auth_token}"
      }

      ids.map do |id|
        query_hash[:id] = id
        record = request_get(url, query_hash, header)
        if block_given?
          yield record
        else
          record["result"]
        end
      end
    end

    # == list 에서 모든 데이터를 요청합니다.
    def request_lists(url, body, header)
      body[:token] = ""
      data = []
      while body[:token].nil? == false
        each_data = request_post(url, body, header)
        body[:token] = each_data["result"]["next_token"]
        data << if block_given?
                  yield each_data
                else
                  each_data
                end
      end
      data.flatten
    end

    def request_get(endpoint, params, headers)
      Faraday.new(endpoint, params) do |conn|
        conn.request :retry, max: 5, interval: 1

        return conn.get { |req| req.headers.merge!(headers) }
      end
    end

    def request_post(endpoint, body, header)
      Faraday.new(endpoint) do |conn|
        conn.request(:retry, max: 5, interval: 1, exceptions: ['Timeout::Error'])

        response = conn.post do |req|
          req.headers.merge!(header)
          req.body = body.to_json
        end

        return JSON.parse(response.body)
      end
    end

    ### === 데이터를 정제하는 로직입니다.


    ## === product 데이터를 정제합니다.

    def form_variants(product)
      variants = product["variants"]

      # variants 가 빈배열인 데이터가 있다.
      # 이 경우, default 옵션 데이터를 만들어 줄 필요가 있다.
      return [
        {
          id: product["id"],
          name: 'default',
          price: product["price"]
        }
      ] if variants.empty?

      variants.map do |variant|
        {
          id: variant["variant_sku"],
          name: variant["variant_sku"],
          price: variant["variant_price"]
        }
      end
    end

    ## === order 데이를 정제합니다.

    def cancelled_status(order_status)
      if order_status == 13
        map_order_status(order_status)
      else
        nil
      end
    end

    def shipping_status(order_status)
      if [6,7,8].include? order_status
        map_order_status(order_status)
      else
        nil
      end
    end

    # == 센도의 결제 방법(숫자) 글자로 바꿔주는 함수입니다.
    # == TODO: 주문 상태 리펙토링 후 아래 로직을 수정해야 합니다.
    # == 우리의 판매 방법의 수가 센도의 판매 방법의 수 보다 같거나 많을 것이라고 판단하여 아래와 같이 case 구문으로 구현하였습니다.
    def map_pay_method(sendo_pay_method)
      case sendo_pay_method
      when 1
        'COD'
      when 2
        'Senpay'
      when 4
        'Combine'
      when 5
        'PayLater'
      else
        nil
      end
    end

    # == 센도의 주문상태(숫)를 글자로 바꿔주는 함수입니다.
    # == TODO: 주문 상태 리펙토링 후 아래 로직을 수정해야 합니다.
    # == 우리의 주문 상태가 센도의 주문 상태보다 수가 적을 것이라고 판단하여 아래와 같이 array로 구현하였습니다.
    def map_order_status(sendo_order_status)
      allowed_order_status = {
        'New': [2],
        'Proccessing': [3],
        'Shipping': [6],
        'POD': [7],
        'Completed': [8],
        'Closed': [10],
        'Delaying': [11],
        'Delay': [12],
        'Cancelled': [13],
        'Splitting': [14],
        'Splitted': [15],
        'Merging': [19],
        'Returning': [21],
        'Returned': [22],
        'WaitingSendo': [23]
      }
      order_status = allowed_order_status.select {|key, value| value.include?(sendo_order_status)}
      if order_status.empty?
        nil
      else
        order_status.keys[0].to_s
      end
    end
  end
end