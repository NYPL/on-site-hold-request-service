require_relative 'platform_api_model'
require_relative 'marc_in_json_model'

class NyplPatron
  include PlatformApiModel
  include MarcInJsonModel

  def initialize (data)
    @data = data
  end

  ##
  # Bring sanity to this confounding capitalization
  def barcodes
    @data['barCodes']
  end

  def ptype
    fixed_field('Patron Type')
  end

  def self.by_id (id)
    resp = self.platform_client.get "patrons/#{id}"

    raise NotFoundError, 'patron not found' unless resp["data"] && resp["data"]

    self.new resp["data"]
  end
end
