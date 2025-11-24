# frozen_string_literal: true
require "net/http"
require "uri"
require "json"

class MailganerClient
  class ApiError < StandardError
    attr_reader :code, :body
  end
  class StopListError < ApiError; end
  class DomainNotTrustedError < ApiError; end
  class AuthorizationError < ApiError; end
  class BadRequestError < ApiError; end

  def initialize(api_key:, smtp_login:, api_key_web_portal:, host: 'https://api.samotpravil.ru/')
    @api_key = api_key
    @api_key_web_portal = api_key_web_portal
    @host = host.chomp('/') + '/'
    @smtp_login = smtp_login
  end

  private

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

    puts "==== HTTP DEBUG ===="
    puts "Method: #{method.upcase}"
    puts "URL: #{uri}"
    puts "Headers: #{req.each_header.to_h}"
    puts "Body: #{req.body}" if req.body
    puts "==================="

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

  def validate_email!(email)
    raise ApiError, 'Invalid email' unless email =~ URI::MailTo::EMAIL_REGEXP
  end

  public

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
      x_track_id: "#{@smtp_login}-#{Time.current.to_i}-#{SecureRandom.hex(6)}",
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

  def stop_emails_package(pack_id:)
    params = { key: @api_key, pack_id: pack_id }
    request('GET', "api/v1/package_stop", params)
  end

  def status_emails_package(pack_id:)
    params = { issuen: pack_id}
    request('GET', "api/v2/package/status", params)
  end

  def status_email_delivery(email: nil, x_track_id: nil, message_id: nil)
    params = { email: email, x_track_id: x_track_id, message_id: message_id }.compact
    request('GET', "api/v2/issue/status", params)
  end

  def get_statistics(date_from:, date_to:, limit: 100, cursor_next: nil, timestamp_from: nil, timestamp_to: nil)
    #?date_from=2023-11-01&date_to=2023-11-07
    #?timestamp_from=1706795600&timestamp_to=1706831999&
    params = {
      date_from: date_from,
      date_to: date_to,
      limit: limit,
      cursor_next: cursor_next,
    }

    if timestamp_from.present? && timestamp_to.present?
      params[:timestamp_from] = timestamp_from
      params[:timestamp_to] = timestamp_to
    elsif date_from.present? && date_to.present?
      params[:date_from] = date_from
      params[:date_to] = date_to
    end

    params.compact!
    request('GET', "api/v2/issue/statistics", params)
  end

  def get_non_delivery_by_date(date_from:, date_to:, limit: 5, cursor_next: nil, order: nil)
    params = { date_from: date_from, date_to: date_to, limit: limit, cursor_next: cursor_next, order: order }.compact
    request('GET', "api/v2/blist/report/non-delivery", params)
  end

  def get_non_delivery_by_issue(issue:, limit: 5, cursor_next: nil, order: nil)
    params = { issuen: issue, limit: limit, cursor_next: cursor_next, order: order }.compact
    request('GET', "api/v2/issue/report/non-delivery", params)
  end

  def get_fbl_report_by_date(date_from:, date_to:, limit: 5, cursor_next: nil)
    params = { date_from: date_from, date_to: date_to, limit: limit, cursor_next: cursor_next }.compact
    request('GET', "api/v2/blist/report/fbl", params)
  end

  def get_fbl_report_by_issue(issue:, limit: 5, cursor_next: nil)
    params = { issuen: issue, limit: limit, cursor_next: cursor_next }.compact
    request('GET', "api/v2/issue/report/fbl?", params)
  end

  def stop_list_search(email:)
    validate_email!(email)
    request('GET', 'api/v2/stop-list/search', { email: email })
  end

  def stop_list_add(email:, mail_from:)
    validate_email!(email)
    request('POST', "api/v2/stop-list/add?#{URI.encode_www_form(mail_from: mail_from, email: email)}", nil, true)
  end

  def stop_list_remove(email:, mail_from:)
    validate_email!(email)
    request('POST', "api/v2/stop-list/remove?#{URI.encode_www_form(mail_from: mail_from, email: email)}", nil, true)
  end

  def domain_check_verification(domain:,client_name:)
    request('POST',"api/v2/blist/domains/verify", {domain: domain, client: client_name})
  end

  def domains_add(domain:)
    params = { domain: domain }
    request('POST',"api/v2/blist/domains/add", params)
  end

  def domains_remove(domain:)
    params = { domain: domain }
    request('POST', "api/v2/blist/domains/remove", params)
  end

  def domains_list
    request('GET', "api/v2/blist/domains")
  end
end