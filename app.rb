require 'uri'
require 'json'
require 'nypl_log_formatter'

require_relative 'lib/on_site_hold_request'

def init
  return if $initialized

  # Instantiate a global logger
  $logger = NyplLogFormatter.new(STDOUT, level: ENV['LOG_LEVEL'] || 'info')

  # Load swagger doc into memory
  $swagger_doc = JSON.load(File.read('./swagger.json'))

  $initialized = true
end

def handle_event(event:, context:)
  init

  path = event["path"]
  method = event["httpMethod"].downcase

  $logger.debug "Handling #{method} #{path}"

  begin
    response = nil
    if method == 'get' && path == "/docs/on-site-hold-requests"
      # Serve swagger doc
      return respond 200, $swagger_doc
    elsif method == 'post' && path == '/api/v0.1/on-site-hold-requests'
      # Handle OnSiteHoldRequest creation
      response = handle_create_hold_request event
    else
      return respond 400, 'Bad method'
    end
    respond response[:statusCode], response

  rescue ParameterError => e
    respond 400, message: "ParameterError: #{e.message}"
  rescue NotFoundError => e
    respond 404, message: "NotFoundError: #{e.message}"
  rescue => e
    $logger.error("Error #{e.backtrace}")

    respond 500, message: e.message
  end
end

def handle_create_hold_request(event)
  params = parse_body event

  $logger.debug "OnSiteHoldRequest.new(#{params.to_json}).process_hold()"
  hold_request = OnSiteHoldRequest.new(params)
  hold_request.process_hold()

  hold_request.is_duplicate? ? {
    statusCode: 200,
    message: "Hold already created"
  } : {
    statusCode: 201,
    message: "Hold created"
  }
end

def parse_body(event)
  # If no body, return empty hash
  return {} unless event.is_a?(Hash) && event['body']

  params = event['body']
  params = Base64.decode64 params if event['isBase64Encoded']
  JSON.parse params
end

def respond(statusCode = 200, body = nil)
  $logger.debug("Responding with #{statusCode}", body)

  {
    statusCode: statusCode,
    body: { statusCode: statusCode }.merge(body).to_json,
    headers: {
      "Content-type": "application/json"
    }
  }
end
