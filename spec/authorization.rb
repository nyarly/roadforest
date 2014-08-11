require 'roadforest/authorization'

describe RoadForest::Authorization do
  subject :manager do
    RoadForest::Authorization::Manager.new.tap do |manager|
      manager.authenticator.add_account("user","secret","")
    end
  end

  def req_with_header(header)
    req = double("Webmachine::Request")
    req.stub(:headers).and_return({"Authorization" => header})
    req
  end

  def req_with_cert(file)
    cert = OpenSSL::X509::Certificate.new(File.read(file))
    req = double("Webmachine::Request")
    req.stub(:headers).and_return({})
    req.stub(:client_cert).and_return(cert)
  end

  describe "default setup" do
    let :requires_admin do
      manager.build_grants do |grants|
        grants.add(:admin)
      end
    end

    it "should refuse an unauthenticated user" do
      manager.authorization(req_with_header(nil), requires_admin).should == :refused
    end

    it "should grant an authenticated user" do
      manager.authorization(req_with_header("Basic #{Base64.encode64("user:secret")}"), requires_admin).should == :granted
    end

    it "should refuse a garbage authentication header" do
      manager.authorization(req_with_header("some garbage here"), requires_admin).should == :refused
    end

    it "should construct a valid challenge header" do
      manager.challenge(:realm => "This test here").should == 'Basic realm="This test here"'
    end
  end
end
