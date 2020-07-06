require_relative 'platform_api_model'
require_relative 'marc_in_json_model'

class Bib
  include PlatformApiModel
  include MarcInJsonModel

  def initialize (data)
    @data = data
  end

  def standard_number
    var_field 947, 'a'
  end

  def self.by_id (nypl_source, id)
    resp = platform_client.get "bibs/#{nypl_source}/#{id}"

    raise NotFoundError, 'item not found' unless resp["data"] && resp["data"]

    self.new resp["data"]
  end
end
