require File.expand_path '../minitest_helper.rb', __FILE__


describe Logvoyage do
  describe "version" do
    it "should has version number" do
      ::Logvoyage::VERSION.must_be_instance_of String
    end
  end

  describe "severity" do
    it "should have severity" do
      ::Logvoyage::Levels::DEBUG.must_be :<, ::Logvoyage::Levels::INFO
      ::Logvoyage::Levels::INFO.must_be :<, ::Logvoyage::Levels::WARN
      ::Logvoyage::Levels::WARN.must_be :<, ::Logvoyage::Levels::ERROR
      ::Logvoyage::Levels::ERROR.must_be :<, ::Logvoyage::Levels::FATAL
      ::Logvoyage::Levels::FATAL.must_be :<, ::Logvoyage::Levels::UNKNOWN
    end
  end
end
