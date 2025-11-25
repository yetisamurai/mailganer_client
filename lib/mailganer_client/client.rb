# frozen_string_literal: true
require "net/http"
require "uri"
require "json"

module MailganerClient
  class Client
    ##
    # Initializes API client
    #
    # @param api_key [String]  SMTP API key for sending
    # @param smtp_login [String] SMTP login 
    # @param api_key_web_portal [String] API key for web portal
    # @param debug [Boolean] enable HTTP debug logging
    # @param host [String] base API URL
    #

    def initialize(
        api_key: MailganerClient.configuration&.api_key,
        smtp_login: MailganerClient.configuration&.smtp_login,
        api_key_web_portal: MailganerClient.configuration&.api_key_web_portal,
        host: MailganerClient.configuration&.host || "https://api.samotpravil.ru/",
        debug: MailganerClient.configuration&.debug || false
      )
      @api_key = api_key
      @api_key_web_portal = api_key_web_portal
      @host = host.chomp('/') + '/'
      @smtp_login = smtp_login
      @debug = debug
    end

    private

    ##
    # Executes a HTTP request
    #
    # @param method [String] HTTP method (GET/POST)
    # @param endpoint [String] API endpoint
    # @param data [Hash,nil] request body
    # @param without_content_type [Boolean] remove Content-Type header
    #
    # @return [Hash] parsed JSON response
    # @raise [ApiError] if API returns an error
    #

    def request(method, endpoint, data = nil, without_content_type = false)
      uri = URI.join(@host, endpoint)

      if (method.upcase == 'GET' && data)
        uri.query = URI.encode_www_form(data)
      end

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.read_timeout = 10

      req = case method.upcase
            when 'GET' then Net::HTTP::Get.new(uri)
            when 'POST' then Net::HTTP::Post.new(uri)
            else raise ApiError, "Unsupported method #{method}"
            end

      if !without_content_type
        req['Content-Type'] = 'application/json'
      end
      req['Authorization'] = @api_key
      req['Mg-Api-Key'] = @api_key_web_portal

      req.body = data.to_json if data

      if (@debug)
        puts "==== HTTP DEBUG ===="
        puts "Method: #{method.upcase}"
        puts "URL: #{uri}"
        puts "Headers: #{req.each_header.to_h}"
        puts "Body: #{req.body}" if req.body
        puts "==================="
      end

      begin
        res = http.request(req)
      rescue Timeout::Error
        raise ApiError, 'Request timed out'
      rescue SocketError => e
        raise ApiError, e&.message
      end

      json = JSON.parse(res.body, symbolize_names: true)

      unless res.code.to_i == 200 && json[:status].to_s.downcase == "ok"
        message = json[:message] || "API error"

        if message.include?("550 bounced check filter")
          raise StopListError, message
        elsif message.include?("from domain not trusted")
          raise DomainNotTrustedError, message
        elsif res.code.to_i == 403
          raise AuthorizationError, message
        elsif res.code.to_i == 400
          raise BadRequestError, message
        else
          raise ApiError, message
        end
      end

      json
    end

    ##
    # Validates email format
    #
    # @param email [String]
    # @raise [ApiError] if invalid
    #

    def validate_email!(email)
      raise ApiError, 'Invalid email' unless email =~ URI::MailTo::EMAIL_REGEXP
    end

    public

    ##
    # Sends a simple email
    #
    # @param to [String] recipient email
    # @param subject [String] subject line
    # @param body [String,nil] message body
    # @param from [String] sender email
    # @param name_from [String,nil] sender name
    # @param params [Hash,nil] template params
    #
    # @return [Hash]
    #

    def send_email(to:, subject:, body: nil, from:, name_from: nil, params: nil)
      validate_email!(to)
      validate_email!(from)

      data = {
        email_to: to,
        subject: subject,
        params: params,
        message_text: body,
        email_from: name_from ? "#{name_from} <#{from}>" : from,
      }
      request('POST', 'api/v2/mail/send', data)
    end

    ##
    # Sends email using SMTP v1 (template or raw body)
    #
    # @param type [String] "template" or "body"
    # @param to [String]
    # @param subject [String]
    # @param body [String,nil]
    # @param from [String]
    # @param name_from [String,nil]
    # @param template_id [Integer,nil]
    # @param params [Hash,nil]
    # @param attach_files [Array]
    #
    def send_email_smtp_v1(type:, to:, subject:, body: nil, from:, name_from: nil, template_id: nil, params: nil, attach_files: [])
      validate_email!(to)
      validate_email!(from)

      data = {
        email_to: to,
        subject: subject,
        params: params,
        check_local_stop_list: true,
        track_open: true,
        track_click: true,
        email_from: name_from ? "#{name_from} <#{from}>" : from,
        attach_files: attach_files,
        x_track_id: "#{@smtp_login}-#{Time.now.to_i}-#{SecureRandom.hex(6)}",
      }

      case type
      when 'template'
        data[:template_id] = template_id
      when 'body'
        data[:message_text] = body
      else
        raise ApiError, "Unsupported type #{type}; select type = template or type = body"
      end

      request('POST', "api/v1/smtp_send?key=#{@api_key}", data)
    end

    ##
    # Sends a bulk email package
    #
    # @param users [Array<Hash>] recipient data
    # @param subject [String]
    # @param body [String]
    # @param from [String]
    # @param name_from [String,nil]
    #
    def send_emails_package(users:, subject:, body:, from:, name_from: nil)
      validate_email!(from)

      # "users": [
      #   {
      #     "emailto": "to1@domain.com", // Имейл получателя
      # "name": "Вася", // любые переменные
      # "field1": "400",
      #   "products": [
      #   {
      #     "name":"foo1",
      #     "price":"bar1",
      #     "link":"baz1"
      #   },
      #   {
      #     "name":"foo2",
      #     "price":"bar2",
      #     "link":"baz2"
      #   }
      # ] // пример вложенного массива
      #     },
      #     {
      #         "emailto": "to2@domain.com",
      #         "string_array": [
      #             {"name": "foo1"},
      #             {"name": "foo2"}
      #         ] // пример массива строк
      # },
      #   {
      #     ...
      #   }
      # ] // массив с получателями

      data = {
        email_from: from,
        name_from: name_from,
        subject: subject,
        check_local_stop_list: true,
        track_open: true,
        track_click: true,
        message_text: body,
        users: users
      }

      request('POST', "api/v1/add_json_package?key=#{@api_key}", data)
    end

    ##
    # Stops a bulk email package
    #
    # @param pack_id [Integer]
    #
    def stop_emails_package(pack_id:)
      params = { key: @api_key, pack_id: pack_id }
      request('GET', "api/v1/package_stop", params)
    end


    ##
    # Gets status of a bulk package
    #
    # @param pack_id [Integer]
    #
    def status_emails_package(pack_id:)
      params = { issuen: pack_id}
      request('GET', "api/v2/package/status", params)
    end

    ##
    # Gets delivery status of a specific message
    #
    # @param email [String,nil]
    # @param x_track_id [String,nil]
    # @param message_id [String,nil]
    #
    def status_email_delivery(email: nil, x_track_id: nil, message_id: nil)
      params = { email: email, x_track_id: x_track_id, message_id: message_id }.compact
      request('GET', "api/v2/issue/status", params)
    end

    ##
    # Retrieves statistics
    #
    # @param date_from [String]
    # @param date_to [String]
    # @param limit [Integer]
    # @param cursor_next [String,nil]
    # @param timestamp_from [Integer,nil]
    # @param timestamp_to [Integer,nil]
    #
    def get_statistics(date_from:, date_to:, limit: 100, cursor_next: nil, timestamp_from: nil, timestamp_to: nil)
      #?date_from=2023-11-01&date_to=2023-11-07
      #?timestamp_from=1706795600&timestamp_to=1706831999&
      params = {
        date_from: date_from,
        date_to: date_to,
        limit: limit,
        cursor_next: cursor_next,
      }

      if timestamp_from && timestamp_to
        params[:timestamp_from] = timestamp_from
        params[:timestamp_to] = timestamp_to
      elsif date_from && date_to
        params[:date_from] = date_from
        params[:date_to] = date_to
      end

      params.compact!
      request('GET', "api/v2/issue/statistics", params)
    end


    ##
    # Non-delivered emails by date
    #
    def get_non_delivery_by_date(date_from:, date_to:, limit: 5, cursor_next: nil, order: nil)
      params = { date_from: date_from, date_to: date_to, limit: limit, cursor_next: cursor_next, order: order }.compact
      request('GET', "api/v2/blist/report/non-delivery", params)
    end

    ##
    # Non-delivered emails by issue
    #
    def get_non_delivery_by_issue(issue:, limit: 5, cursor_next: nil, order: nil)
      params = { issuen: issue, limit: limit, cursor_next: cursor_next, order: order }.compact
      request('GET', "api/v2/issue/report/non-delivery", params)
    end

    ##
    # FBL (abuse complaints) by date
    #
    def get_fbl_report_by_date(date_from:, date_to:, limit: 5, cursor_next: nil)
      params = { date_from: date_from, date_to: date_to, limit: limit, cursor_next: cursor_next }.compact
      request('GET', "api/v2/blist/report/fbl", params)
    end

    ##
    # FBL (abuse complaints) by issue
    #
    def get_fbl_report_by_issue(issue:, limit: 5, cursor_next: nil)
      params = { issuen: issue, limit: limit, cursor_next: cursor_next }.compact
      request('GET', "api/v2/issue/report/fbl?", params)
    end

    ##
    # Searches email in stop-list
    #
    # @param email [String]
    #
    def stop_list_search(email:)
      validate_email!(email)
      request('GET', 'api/v2/stop-list/search', { email: email })
    end

    ##
    # Adds email to stop-list
    #
    def stop_list_add(email:, mail_from:)
      validate_email!(email)
      request('POST', "api/v2/stop-list/add?#{URI.encode_www_form(mail_from: mail_from, email: email)}", nil, true)
    end

    ##
    # Removes email from stop-list
    #
    def stop_list_remove(email:, mail_from:)
      validate_email!(email)
      request('POST', "api/v2/stop-list/remove?#{URI.encode_www_form(mail_from: mail_from, email: email)}", nil, true)
    end


    ##
    # Checks domain verification status
    #
    def domain_check_verification(domain:,client_name:)
      request('POST',"api/v2/blist/domains/verify", {domain: domain, client: client_name})
    end

    ##
    # Adds domain
    #
    def domains_add(domain:)
      params = { domain: domain }
      request('POST',"api/v2/blist/domains/add", params)
    end

    ##
    # Removes domain
    #
    def domains_remove(domain:)
      params = { domain: domain }
      request('POST', "api/v2/blist/domains/remove", params)
    end

    ##
    # Lists all domains
    #
    # @return [Hash]
    #
    def domains_list
      request('GET', "api/v2/blist/domains")
    end
  end
end