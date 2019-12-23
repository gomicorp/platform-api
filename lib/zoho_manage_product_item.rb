module ZohoManageProductItem
  include ZohomapLib, ManageContainerRow

  ### select create or update product_item ###
  # product_item 들을 생성하거나 업데이트 한다. (업데이트는 작성중)
  def create_or_update_product_items(items)
    objects = []

    items.each do |item|  
      # item 유뮤 확인
      product_item = check_existed_product_item(item["item_id"])

      # item 없으면 create, 있으면 최근수정 날짜 확인후 업데이트 진행
      if product_item == nil && item["is_combo_product"] == false
        object = create_product_item_procedure(item)
        objects.push(object)
      elsif product_item != nil
        objects.push(product_item)
      end
    end

    return objects
  end  

  ### ### create logics ### ###
  #product_item을 추가하는 절차를 시행한다.
  def create_product_item_procedure(item)
    # example: "name": "그라펜-스킨-100ml/동그라미"
    brand_name, product_item_group_name, options = item["name"].split('-') 

    # brand 반환 (ㅇ)
    brand = get_or_create_brand(name=brand_name)

    # product_item_group 저장후 반환 (ㅇ)
    product_item_group = get_or_create_product_item_group(brand, name=product_item_group_name, item["group_id"])

    # product_item_attribute들과 option들을 저장한후 반환한다 (ㅇ)
    get_or_create_attributes_with_options(item, options, product_item_group)

    #product_item 생성후 반환
    product_item = create_product_item(product_item_group, item["item_id"], item["name"], item["purchase_rate"], item["rate"])

    #product_item_container 생성후 반환
    product_item_container = create_product_item_container(product_item)

    #product_item_row 생성
    create_product_item_row(product_item[:id], product_item_container[:id], 1)

    return product_item
  end

  #brand를 새로 생성한다
  def create_brand(name)
    object = Brand.new
    object[:name] = name
    object.save
    return object
  end

  #brand를 새로만들거나 반환한다.
  def get_or_create_brand(name)
    object = Brand.find_by(name: name)
    if object == nil
      object = create_brand(name)
    end
    return object
  end
  
  #product_item_group를 새로 생성한다.
  def create_product_item_group(brand, name)
    object = brand.product_item_groups.new
    object[:name] = name
    object.save
    return object
  end
  
  # product_item_group을 만들거나 반환한다.
  def get_or_create_product_item_group(brand, name, zoho_id)
    zoho_map_object = object_by_zoho_id(zoho_id)
    if zoho_map_object == nil      
      object = create_product_item_group(brand, name)
      create_zohomap(object, zoho_id)
      return object
    end
    return zoho_map_object.zohoable
  end
  
  # product_attribute들과 option들을 만든다.
  def get_or_create_attributes_with_options(item, options, product_item_group)
    # options이 존재할때만 아래 과정 수행 (ㅇ)
    if options != ""
      # attributes 저장후 반환 (ㅇ)
      attribute_infos = item.select{|k, v| k =~ /^(?=.*attribute)(?!.*option).*/}
      product_attributes = get_or_create_product_attributes(product_item_group, attribute_infos)

      # 반환된 attributes 정보를 이용해서 attribute_option 저장 (ㅇ)
      product_attribute_option_infos = item.select{|k, v| k =~ /^(?=.*attribute)(?=.*option).*/}
      product_attribute_options = get_or_create_product_attribute_options(product_attributes, product_attribute_option_infos)
    end
  end

  # product_attribute들을 만들거나 반환한다.
  def get_or_create_product_attributes(product_item_group, infos)
    #id 배열 뽑아내고
    ids = infos.select{|k, v| k =~ /^(?=.*id).*/}.values
  
    #name 배열 뽑아내고
    names = infos.select{|k, v| k =~ /^(?=.*name).*/}.values
  
    #새롭거나 이미 만들어진 attribute를 반환하고
    #attributes에 push한다.
    objects = []
    ids.each_with_index do |id, index|
      if id != ""
        object = get_or_create_product_attribute(product_item_group, id, names[index])
        objects.push(object)
      end
    end
      
    #완성된 attributes를 반환한다
    return objects
  end
  
  # product_attribute를 만든다.
  def create_product_attribute(name)
    object = ProductAttribute.new
    object[:name] = name
    object.save
    return object
  end

  # product_attribute를 만들거나 반환한다.
  def get_or_create_product_attribute(product_item_group, zoho_id, name)
    # find product_attribute
    zoho_map_object = object_by_zoho_id(zoho_id)
  
    # if not found, create new product_attribute
    if zoho_map_object == nil
      object = create_product_attribute(name)
      zoho_map_object = create_zohomap(object, zoho_id)
    end
  
    get_or_create_product_attribute_product_item_group(zoho_map_object.zohoable, product_item_group)
  
    return zoho_map_object.zohoable
  end
  
  # product_attribute, product_item_group사이의 관계 테이블에 행을 추가한다.
  def create_product_attribute_product_item_group(product_attribute, product_item_group)
    object = ProductAttributeProductItemGroup.create(
      :product_item_group_id => product_item_group[:id], 
      :product_attribute_id => product_attribute[:id]
    )
    return object
  end

  # product_attribute, product_item_group사이의 관계 테이블에 행을 추가하거나 반환한다.
  def get_or_create_product_attribute_product_item_group(product_attribute, product_item_group)
    object = product_item_group.product_attributes.find_by_id(id=product_attribute[:id])

    if object == nil
      object = create_product_attribute_product_item_group(product_attribute, product_item_group)
    end
    
    return object
  end
  
  #product_attribute_option들을 추가하거나 업데이트 한다.
  def get_or_create_product_attribute_options(product_attributes, infos)
    #id 배열 뽑아내고
    ids = infos.select{|k, v| k =~ /^(?=.*id).*/}.values
  
    #name 배열 뽑아내고
    names = infos.select{|k, v| k =~ /^(?=.*name).*/}.values
  
    #새롭거나 이미 만들어진 option를 반환하고
    #options에 push한다.
    objects = []
    ids.each_with_index do |id, index|
      if id != ""
        object = get_or_create_product_attribute_option(product_attributes[index], id, names[index])
        objects.push(object)
      end
    end
      
    #완성된 attributes를 반환한다
    return objects
  end
  
  # product_attribute_option을 추가한다
  def create_product_attribute_option(product_attribute, name)
    object = product_attribute.options.new
    object[:name] = name
    object.save
    return object
  end

  # product_attribute_option을 추가하거나 반환한다.
  def get_or_create_product_attribute_option(product_attribute, zoho_id, name)
    zoho_map_object = object_by_zoho_id(zoho_id)
  
    if zoho_map_object == nil
      object = create_product_attribute_option(product_attribute, name)
      zoho_map_object = create_zohomap(object, zoho_id)
    end
  
    return zoho_map_object.zohoable
  end

  # 현재 product_item이 존재하는지 확인한다
  def check_existed_product_item(id)
    product_item = Zohomap.find_by(zoho_id: id)
    if product_item
      return product_item
    else
      return nil
    end
  end

  #product_item을 추가한다.
  def create_product_item(product_item_group, id, name, cost_price, selling_price)
    object = product_item_group.items.new
    object[:name] = name
    object[:cost_price] = cost_price
    object[:selling_price] = selling_price
    object.save
    create_zohomap(object, id)
    return object
  end

  ### ### update logics ### ###
  # 오브젝트의 내용을 업데이트 한다
  def update_object(object, name)
    if object[:name] != name
      object[:name] = name
      object.save
    end
  end

  #product_item을 업데이트 하기 위한 절차 (작성중)
  def update_product_item_procedure(item, object)
    # example: "name": "그라펜-스킨-100ml/동그라미"
    brand_name, product_item_group_name, options = item["name"].split('-') 

    # brand 받아오기 (ㅇ)
    brand = get_or_create_brand(name=brand_name)

    # product 압데이트후 반환 (ㅇ)
    product_item_group = get_or_create_product_item_group(brand, name=product_item_group_name, item["group_id"])
    update_object(product_item_group, product_item_group_name)

    # options이 존재할때만 아래 과정 수행 (ㅇ)
    if options != ""
      # attributes 저장후 반환 (ㅇ)
      attribute_infos = item.select{|k, v| k =~ /^(?=.*attribute)(?!.*option).*/}
      product_attributes = get_and_update_or_create_product_attributes(product_item_group, attribute_infos)

      # attribute_option 저장 (ㅇ)
      product_attribute_option_infos = item.select{|k, v| k =~ /^(?=.*attribute)(?=.*option).*/}
      product_attribute_options = get_and_update_or_create_product_attribute_options(product_attributes, product_attribute_option_infos)
    end

    #item 업데이트후 반환
    update_object(object, item["name"])
    return object
  end
end