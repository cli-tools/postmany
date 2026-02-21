struct Postmany::Domain::TransferContext
  getter endpoint : Endpoint
  getter method : TransferMethod
  getter workers : Int32
  getter silent : Bool
  getter progress : Bool
  getter static_headers : Hash(String, String)

  def initialize(@endpoint : Endpoint,
                 @method : TransferMethod,
                 @workers : Int32,
                 @silent : Bool,
                 @progress : Bool,
                 static_headers : Hash(String, String))
    @static_headers = static_headers.dup
  end
end
