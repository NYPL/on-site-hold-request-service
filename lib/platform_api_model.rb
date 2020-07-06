require 'nypl_platform_api_client'

module PlatformApiModel
  def method_missing(name, *args)
    name = name.to_s
    @data[name] if @data.keys.include? name
  end

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
