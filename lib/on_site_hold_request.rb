require 'date'

require_relative 'sierra_model'
require_relative 'errors'

class OnSiteHoldRequest < SierraModel
  def self.create(params = {})
    raise ParameterError, 'record is required' unless params['record']
    raise ParameterError, 'patron is required' unless params['patron']

    patron_id = params['patron']
    pickup_location = params['pickupLocation']

    is_edd = ! params.dig('docDeliveryData', 'emailAddress').nil?

    if is_edd
      # TODO get item from ItemService
      #
      # TODO establish pickup_location based on item holdingLocation
    end

    hold = {
      'recordType' => 'i',
      'recordNumber' => params['record'],
      'pickupLocation' => pickup_location,
      'neededBy' => params['neededBy'],
      'numberOfCopies' => params['numberOfCopies'],
      'note' => ''
    }

    # See https://sandbox.iii.com/iii/sierra-api/swagger/index.html#!/patrons/Place_a_new_hold_request_post_24
    # response = self.sierra_client.post "patrons/#{patron_id}/holds/requests", hold
    $logger.debug "self.sierra_client.post \"patrons/#{patron_id}/holds/requests\", #{hold.to_json}"

    if is_edd
      # TODO Get patron from PatronService
      #
      # TODO send LibAnswers email
    end

    {
      statusCode: 201
    }
  end
end
