struct Postmany::Ports::HttpRequest
  getter method : Postmany::Domain::TransferMethod
  getter path : String
  getter query : String?
  getter headers : Hash(String, String)
  getter body : String?

  def initialize(@method : Postmany::Domain::TransferMethod,
                 @path : String,
                 @query : String?,
                 headers : Hash(String, String),
                 @body : String?)
    @headers = headers.dup
  end

  def path_with_query : String
    return @path if @query.nil?
    "#{@path}?#{@query}"
  end
end

struct Postmany::Ports::HttpResponse
  getter status_code : Int32
  getter body : String

  def initialize(@status_code : Int32, @body : String = "")
  end
end

abstract class Postmany::Ports::HttpTransport
  abstract def perform(request : HttpRequest) : HttpResponse
end
