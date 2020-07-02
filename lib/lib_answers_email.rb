require "erb"
require "aws-sdk-ses"

class LibAnswersEmail
  EMAIL_ENCODING = "UTF-8"
  EMAIL_SENDER = 'on-site-hold-request-service@nypl.org'

  def initialize(on_site_hold_request)
    @hold_request = on_site_hold_request
  end

  def destination_email
    # FIXME: This is waiting on a real mapping:
    case @hold_request.item.location_code[(0...2)]
    when 'ma'
      ENV['LIB_ANSWERS_DEFAULT_DESTINATION_EMAIL']
    end
  end

  def body
    erb = ERB.new(File.read("./email/lib_answers_email.erb")).result binding
  end

  def send
    $logger.debug "Send libanswers email: #{body}"

    ses = Aws::SES::Client.new(region: 'us-east-1')

    # Try to send the email.
    begin
      # Provide the contents of the email.
      resp = ses.send_email({
        destination: {
          to_addresses: [
            destination_email
          ],
        },
        message: {
          body: {
            text: {
              charset: EMAIL_ENCODING,
              data: body
            },
          },
          subject: {
            charset: EMAIL_ENCODING,
            data: 'EDD Hold Request'
          },
        },
        source: EMAIL_SENDER
      })
      $logger.debug "Email sent to #{destination_email}"

    rescue Aws::SES::Errors::ServiceError => error
      $logger.error "Email not sent. Error message: #{error}"
    end
  end

  def self.create(on_site_hold_request)
    self.new(on_site_hold_request).send
  end
end
