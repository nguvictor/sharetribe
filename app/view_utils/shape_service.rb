# A helper module that let's you reload listing shapes by community id or
# community id and listing shape id, and gets back the shape with translations
# and process information included
class ShapeService
  Form = ListingShapeDataTypes::Form
  TR_MAP = ListingShapeDataTypes::TR_KEY_PROP_FORM_NAME_MAP

  def initialize(processes)
    @processes = processes
  end

  def get(community_id:, listing_shape_id:, locales:)
    extended_shape = listing_api.shapes.get(community_id: community_id, listing_shape_id: listing_shape_id).and_then { |shape|
      process = @processes.find { |p| p[:id] == shape[:transaction_process_id] }

      raise ArgumentError.new("Can not find process with id: #{shape[:transaction_process_id]}") if process.nil?

      shape_with_process = shape.merge(online_payments: process[:process] == :preauthorize) # TODO More sophisticated?

      with_translations = TranslationServiceHelper.tr_keys_to_form_values(
        entity: shape_with_process,
        locales: locales,
        key_map: TR_MAP
      )

      Result::Success.new(Form.call(with_translations))
    }
  end

  def update(community_id:, listing_shape_id:, opts:)
    form_opts = Form.call(opts)

    with_translations = TranslationServiceHelper.form_values_to_tr_keys!(
      entity: form_opts,
      key_map: TR_MAP,
      community_id: community_id
    )

    with_units = with_translations.merge(
      units: with_translations[:units].map { |u| add_quantity_selector(u) }
    )

    with_process = with_units.merge(
      transaction_process_id: select_process(with_units[:online_payments], @processes))

    listing_api.shapes.update(
      community_id: community_id,
      listing_shape_id: listing_shape_id,
      opts: with_process
    )
  end

  def create(community_id:, default_locale:, opts:)
    form_opts = Form.call(opts)

    with_translations = TranslationServiceHelper.form_values_to_tr_keys!(
      entity: form_opts,
      key_map: TR_MAP,
      community_id: community_id
    )

    with_basename = with_translations.merge(
      basename: with_translations[:name][default_locale]
    )

    with_units = with_basename.merge(
      units: with_basename[:units].map { |u| add_quantity_selector(u) }
    )

    with_process = with_units.merge(
      transaction_process_id: select_process(with_units[:online_payments], @processes))

    listing_api.shapes.create(
      community_id: community_id,
      opts: with_process
    )
  end

  private

  def listing_api
    ListingService::API::Api
  end

  def add_quantity_selector(unit)
    unit.merge(quantity_selector: unit[:type] == :day ? :day : :number)
  end

  def select_process(online_payments, processes)
    # TODO Maybe more sophisticated version
    author_is_seller = true
    process = online_payments ? :preauthorize : :none

    selected = processes.find { |p| p[:author_is_seller] == author_is_seller && p[:process] == process }

    raise ArugmentError.new("Can not find suitable process") if selected.nil?

    selected[:id]
  end

end