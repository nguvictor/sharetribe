module ListingFormViewUtils
  module_function

  def filter(params, shape)
    filter_fields = []

    filter_fields << :price unless shape[:price_enabled]
    filter_fields << :currency unless shape[:price_enabled]
    filter_fields << :unit unless shape[:units].present?
    filter_fields << :shipping_price unless shape[:shipping_enabled]
    filter_fields << :shipping_price_additional unless shape[:shipping_enabled]
    filter_fields << :delivery_methods unless shape[:shipping_enabled]

    params.except(*filter_fields)
  end

  def validate(params, shape)
    errors = []

    errors << :price_required if shape[:price_enabled] && params[:price].nil?
    errors << :currency_required if shape[:price_enabled] && params[:currency].blank?
    errors << :unit_required if shape[:units].present? && params[:unit].blank?
    errors << :unit_does_not_belong if shape[:units].present? && params[:unit].present? && !shape[:units].any? { |u| u[:type] == params[:unit].to_sym }
    errors << :delivery_method_required if shape[:shipping_enabled] && params[:delivery_methods].empty?
    errors << :unknown_delivery_method if shape[:shipping_enabled] && params[:delivery_methods].any? { |method| !["shipping", "pickup"].include?(method) }

    if errors.empty?
      Result::Success.new
    else
      Result::Error.new("Invalid listing parameters", errors)
    end
  end

end
