
module MailganerClient
    class ApiError < StandardError
      attr_reader :code, :body
    end
    class StopListError < ApiError; end
    class DomainNotTrustedError < ApiError; end
    class AuthorizationError < ApiError; end
    class BadRequestError < ApiError; end
end