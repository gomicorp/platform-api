module ExternalChannel
  class HaravanAdapter < BaseAdapter
    attr_reader :default_headers, :faraday_options

    # === 사용 가능한 PRODUCT query property (공식 API 문서 기준이고, 변경될 가능성이 있습니다)
    # https://docs.haravan.com/blogs/api-reference/1000018172-product
    # === 의미 파악이 어려운 경우에는 원문을 추가로 달아두었습니다.
    {
      # = ids : 상품 id, comma 를 사용해 동시에 여러 상품을 검색할 수 있습니다
      # = limit : 검색 결과로 전달 받는 데이터 갯수 제한
      # = page : 검색할 페이지 number
      # = since_id : 특정 id 이후의 상품들을 검색하는 것으로 "추측" 됩니다
      #   => Restrict results to after the specified ID
      # = vendor : vendor 명으로 검색, vendor 는 고미의 Brand 개념과 같습니다
      # = handle : 상품 title 을 이용해 자동으로 생성되는 인간 친화적 고유 문자열이라고 합니다..
      #   => 'A human-friendly unique string for the Product automatically generated from its title. They are used by the Liquid templating language to refer to objects.'
      # = product_type : product_type 으로 검색, product_type 은 고미의 Category 개념과 유사합니다
      # = collection_id : 베트남 지사에서 브랜드와 유사하게 사용하고 있으나, 이벤트 상품 등도 있어 유의미한 활용은 어렵습니다
      # = created_at_min & created_at_max : 데이터 생성 시간을 기준으로 특정 시점 이전/이후 검색이 가능합니다
      # = updated_at_min & updated_at_max : 데이터 업데이트 시간을 기준으로 특정 시점 이전/이후 검색이 가능합니다
      # = published_at_min & published_at_max : 상품이 개시된 시간을 기준으로 특정 시점 이전/이후 검색이 가능합니다
      # = published_status : 상품 개시 상태로 검색이 가능합니다
      # = fields : response 데이터 중 특정 스키마만 골라서 볼 수 있습니다
    }

    # === 사용 가능한 Order query property (공식 API 문서 기준이고, 변경될 가능성이 있습니다)
    # https://docs.haravan.com/blogs/api-reference/1000018025-order#show
    # === 의미 파악이 어려운 경우에는 원문을 추가로 달아두었습니다.
    {
      # = ids : 주문 id, comma 를 사용해 동시에 여러 상품을 검색할 수 있습니다
      # = limit : 검색 결과로 전달 받는 데이터 갯수 제한
      # = page : 검색할 페이지 number
      # = since_id : 특정 id 이후의 상품들을 검색하는 것으로 "추측" 됩니다
      #   => Restrict results to after the specified ID
      # = created_at_min & created_at_max : 데이터 생성 시간을 기준으로 특정 시점 이전/이후 검색이 가능합니다
      # = updated_at_min & updated_at_max : 데이터 업데이트 시간을 기준으로 특정 시점 이전/이후 검색이 가능합니다
      # = processed_at_min & processed_at_max : 상품이 개시된 시간을 기준으로 특정 시점 이전/이후 검색이 가능합니다
      # = financial_status : 결제 상태로 검색이 가능합니다
      # = fulfillment_status : 배달 상태로 검색이 가능합니다
      # = fields : response 데이터 중 특정 스키마만 골라서 볼 수 있습니다
    }

    QUERY_MAPPER = {
      'created'=> %w[created_at_min created_at_max],
      'updated'=> %w[updated_at_min updated_at_max],
    }

    def initialize
      super
      api_key = Rails.application.credentials.dig(:haravan, :api, :key)
      api_password = Rails.application.credentials.dig(:haravan, :api, :password)

      @default_headers = { 'authorization': 'Basic ' + ["#{api_key}:#{api_password}"].pack('m0') }
    end

    protected

    # == 적절하게 정제된 데이터를 리턴합니다.
    def products(query_hash = {})
      refine_products(call_products(parse_query_hash(QUERY_MAPPER, query_hash)))
    end

    def orders(query_hash = {})
    refine_orders(call_orders(parse_query_hash(QUERY_MAPPER, query_hash)))
    end

    def login; end

    def date_formatter(utc_time)
      utc_time.strftime('%Y-%m-%d %H:%M')
    end

    # == 외부 채널의 API 를 사용하여 각 레코드를 가져옵니다.
    def call_products(query_hash)
      endpoint = 'https://gomicorp.myharavan.com/admin/products.json'
      call_all(endpoint, query_hash, 'products')
    end

    def call_orders(query_hash)
      endpoint = 'https://gomicorp.myharavan.com/admin/orders.json'
      call_all(endpoint, query_hash, 'orders')
    end

    # == call_XXX 로 가져온 레코드를 정제합니다.
    def refine_products(records)
      product_property = []

      records.each do |record|
        product_property << {
          id: record['id'],
          title: record['title'],
          channel_name: 'Haravan',
          brand_name: record['vendor'],
          variants: refine_product_options(record)
        }
      end

      product_property
    end

    def refine_product_options(record)
      variants = record['variants'] || []

      if variants.empty?
        return [
            {
              id: record['id'],
              price: record['price'].to_i,
              name: 'default title'
            }
        ]
      end

      variants.map do |variant|
        {
          id: variant['id'],
          price: variant['price'].to_i,
          name: variant['title']
        }
      end
    end

    def refine_orders(records)
      order_property = []

      records.each do |record|
        next if %w[shopee sendo lazada tiki].include? record['source']

        order_property << {
          id: record['id'],
          order_number: record['name'],
          receiver_name: receiver_name(record),
          order_status: record['financial_status'],
          pay_method: record['gateway'],
          channel: 'haravan',
          ordered_at: record['created_at'].to_time.getutc,
          paid_at: paid_at(record),
          billing_amount: record['total_price'],
          ship_fee: record['shipping_lines'].inject(0) { |sum, line| sum + (line['price']) },
          variant_ids: record['line_items'].map { |variant| [variant['variant_id'], variant['quantity'].to_i, variant['price'].to_i ] },
          cancelled_status: record['cancelled_status'],
          shipping_status: record['fulfillments'].any? ? record['fulfillments'][0]['carrier_status_code'] : 'unknown',
          tracking_company_code: record['fulfillments'].any? ? record['fulfillments'][0]['tracking_company_code'] : nil,
          confirmed_status: record['confirmed_status'],
          source_name: record['source_name'],
          delivered_at: record['fulfillments'].any? ? record['fulfillments'][0]['delivered_date'] : nil,
          payment_status: record['financial_status']
        }
      end

      order_property
    end

    private

    def call_all(end_point, query_hash, target)
      query_hash[:page] ||= 1
      data = []
      response =[1]
      while(!response.empty?)
        temp = request_get(end_point, query_hash, default_headers)
        response = (JSON.parse temp.body)[target.to_s]
        data << response
        query_hash[:page] += 1
      end
      data.flatten
    end

    def paid_at(record)
      if record['gateway'] == 'Thanh toán khi giao hàng (COD)'
        if record['fulfillments'].any? || record['fulfillments'].empty?
          nil
        else
          record['fulfillments'][0]['cod_paid_date'] ? record['fulfillments'][0]['cod_paid_date'].to_time.getutc : nil
        end
      else
        record['created_at'].to_time.getutc
      end
    end

    def receiver_name(record)
      if record['shipping_address'].any?
        first_name = record['shipping_address']['first_name']
        last_name = record['shipping_address']['last_name']

        if first_name && last_name
          first_name + " " + last_name
        elsif first_name
          first_name
        elsif last_name
          last_name
        end
      else
        ""
      end
    end
  end
end
