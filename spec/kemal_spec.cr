require "./spec_helper"

describe Kemal do
  it "render root" do
    get "/"
    response.body.should match(/\>index\spage\</)
  end
end
