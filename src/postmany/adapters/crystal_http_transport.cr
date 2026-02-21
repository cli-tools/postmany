class Postmany::Adapters::CrystalHttpTransport < Postmany::Ports::HttpTransport
  def initialize(endpoint_uri : URI, static_headers : Hash(String, String))
    @endpoint_uri = endpoint_uri
    @static_headers = static_headers.dup
    @clients = {} of Fiber => HTTP::Client
  end

  def perform(request : Postmany::Ports::HttpRequest) : Postmany::Ports::HttpResponse
    headers = HTTP::Headers.new
    request.headers.each { |k, v| headers[k] = v }
    @static_headers.each { |k, v| headers[k] = v }
    client = client_for_current_fiber

    response = case request.method
               when Postmany::Domain::TransferMethod::GET
                 client.get(request.path_with_query, headers)
               when Postmany::Domain::TransferMethod::POST
                 client.post(request.path_with_query, headers, request.body.to_s)
               when Postmany::Domain::TransferMethod::PUT
                 client.put(request.path_with_query, headers, request.body.to_s)
               else
                 raise "Unsupported HTTP method #{request.method}"
               end

    Postmany::Ports::HttpResponse.new(response.status_code, response.body)
  end

  private def client_for_current_fiber : HTTP::Client
    fiber = Fiber.current
    client = @clients[fiber]?
    return client unless client.nil?

    @clients[fiber] = HTTP::Client.new(@endpoint_uri)
    @clients[fiber]
  end
end
