require 'nypl_platform_api_client'

module PlatformApiModel
  ##
  # As a convenience, allow property access to fall through to @data.
  #
  # For example, for an instance of a Bib, bib.author should return
  # @data['author']
  def method_missing(name, *args)
    name = name.to_s
    @data[name] if @data.keys.include? name
  end

  ##
  # Ensure models that include PlatformApiModel have access to
  # class methods like platform_client
  def self.included(o)
    o.extend(ClassMethods)
  end

  module ClassMethods
    # Get NyplPlatformApiClient instance
    def platform_client
      if @platform_client.nil?
        raise 'Missing config: ENV.NYPL_OAUTH_ID is not set' unless ENV['NYPL_OAUTH_ID']
        raise 'Missing config: ENV.NYPL_OAUTH_SECRET is not set ' unless ENV['NYPL_OAUTH_SECRET']
        raise 'Missing config: ENV.NYPL_OAUTH_URL is not set ' unless ENV['NYPL_OAUTH_URL']
        raise 'Missing config: ENV.PLATFORM_API_BASE_URL is not set ' unless ENV['PLATFORM_API_BASE_URL']

        kms = KmsClient.new
        @platform_client = NyplPlatformApiClient.new({
          client_id: kms.decrypt(ENV['NYPL_OAUTH_ID']),
          client_secret: kms.decrypt(ENV['NYPL_OAUTH_SECRET']),
          oauth_url: ENV['NYPL_OAUTH_URL'],
          log_level: 'error'
        })
      end

      @platform_client
    end
  end
end
