module ExternalChannel
  module Product
    # TODO: 방어 로직 추가
    class ExternalChannelProductSaver < ExternalChannel::ExternalChannelSaver
      attr_accessor :brand, :channel, :product

      def save_batch(products)
        products.all? {|product| save(product)}
      end

      def save(data)
        refresh_data
        @channel = Channel.find_by_name(data[:channel_name])
        @brand = find_brand(data[:brand_name])
        save_product(data) && save_options(data[:variants])
      end

      def save_product(product_data)
        @product = ::Product.find_or_initialize_by(haravan_id: product_data[:id].to_i)
        product.assign_attributes(parse_product(product_data))
        product.save!
      end

      private

      def save_options(options)
        option_group = product.option_groups.first_or_create
        options.all? {|option| save_option(option, option_group)}
      end

      def save_option(option, option_group)
        product_option_data = parse_product_option(option)
        product_option = product.options.find_by(channel_code: option[:id])
        if product_option.nil?
          option_group.options << ProductOption.new(product_option_data)
        else
          product_option.update!(product_option_data)
        end
      end

      def refresh_data
        @channel = @product = nil
      end


      def make_valid_title(title)
        unless product.title.nil?
          parsed_product = JSON.parse(product.title)
          parsed_product[country_code] = title
          parsed_product
        else
          # TODO: 나중에는 국가별로 키값을 가지고 돌면서 title을 주입할 수 있도록 처리해야 함.
          {'vn': title, 'en': "(not translated)#{title}", 'ko': "(미번역)#{title}"}
        end
      end

      # TODO: 채널 어소시에이션을 걸어야 함.
      def parse_product(product)
        {
          brand_id: brand.id,
          running_status: 'pending',
          title: make_valid_title(product[:title]),
          country: Country.at(country_code)
        }
      end

      def parse_product_option(variant)
        {
          name: variant[:name],
          channel: channel,
          channel_id: channel.id,
          channel_code: variant[:id],
          additional_price: variant[:price]
        }
      end

    end
  end
end