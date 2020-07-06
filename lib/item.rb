require_relative 'platform_api_model'
require_relative 'marc_in_json_model'
require_relative 'bib'

class Item
  include PlatformApiModel
  include MarcInJsonModel

  def initialize (data)
    @data = data
  end

  def location_code
    @data.dig "location", "code"
  end

  def item_type
    fixed_field('Item Type') { |field| "#{field['value']} (#{field['display']})" }
  end

  def call_number
    var_field 852, 'h'
  end

  def staff_call_number
    var_field 852, 'h'
  end

  def bibs
    return @bibs unless @bibs.nil?

    @bibs = @data['bibIds'].map { |bib_id| Bib.by_id @data['nyplSource'], bib_id }

    @bibs
  end

  def self.by_id (nypl_source, id)
    resp = platform_client.get "items/#{nypl_source}/#{id}"

    raise NotFoundError, 'item not found' unless resp["data"] && resp["data"]

    self.new resp["data"]
  end
end
