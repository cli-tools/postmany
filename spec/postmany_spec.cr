require "./spec_helper"

describe Postmany do
  it "defines a version" do
    Postmany::VERSION.should_not be_nil
  end
end
