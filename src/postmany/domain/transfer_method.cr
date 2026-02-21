enum Postmany::Domain::TransferMethod
  GET
  POST
  PUT

  def self.from_string(raw : String) : self?
    case raw.upcase
    when "GET"
      GET
    when "POST"
      POST
    when "PUT"
      PUT
    else
      nil
    end
  end

  def upload? : Bool
    post? || put?
  end
end
