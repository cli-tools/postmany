struct Postmany::Domain::BatchResult
  getter ok : Int32
  getter skipped : Int32
  getter total : Int32

  def initialize(@ok : Int32, @skipped : Int32, @total : Int32)
  end
end
