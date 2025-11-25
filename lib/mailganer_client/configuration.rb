module MailganerClient
  class Configuration
    attr_accessor :api_key, :smtp_login, :api_key_web_portal, :host, :debug

    def initialize
      @debug = false
      @host  = "https://api.samotpravil.ru/"
    end
  end
end