struct Postmany::Domain::Endpoint
  getter uri : URI

  def initialize(@uri : URI)
  end

  def query : String?
    @uri.query
  end

  def path_for(method : TransferMethod, filename : String? = nil) : String
    path = @uri.path
    path = "/" if path.empty?

    if method.get? || method.put?
      path += "/" unless path.ends_with?("/")
      path += filename unless filename.nil?
    end

    path
  end
end
