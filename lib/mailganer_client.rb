require_relative "mailganer_client/version"
require_relative "mailganer_client/errors"
require_relative "mailganer_client/client"
require_relative "mailganer_client/configuration" 

module MailganerClient
  class << self
    attr_accessor :configuration
  end

  def self.configure
    self.configuration ||= Configuration.new
    yield(configuration)
  end
end