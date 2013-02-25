#! /usr/bin/ruby1.9.1

require File.join([File.dirname(__FILE__), './spec_helper'])

module Puppet
  class Type
  end
end
module MCollective
  class DDLValidationError<RuntimeError;end
end

def pkg_remove(pkg)
  if File.file? "/usr/bin/yum"
    system "yum", "erase", "-y", pkg
    raise "Unable to run yum" unless $? == 0
  elsif File.file? "/usr/bin/apt-get"
    system "apt-get", "remove", "--purge", "-y", pkg
    raise "Unable to run yum" unless $? == 0
  else
    raise "Unsupported pkg system"
  end
end

def pkg_install(pkg, version=nil)
  if File.file? "/usr/bin/yum"
    pkg = "#{pkg}-#{version}" unless version.nil?
    system "yum", "install", "-y", pkg
  elsif File.file? "/usr/bin/apt-get"
    pkg = "#{pkg}=#{version}" unless version.nil?
    system "apt-get", "install", "-y", pkg
  else
    raise "Unsupported pkg system"
  end
end

describe "packages agent" do
  before do
    agent_file = File.join([File.dirname(__FILE__), "../agent/puppet-packages.rb"])
    libdir = [ File.join([File.dirname(__FILE__), "../"]) ]
    @agent = MCollective::Test::LocalAgentTest.new("packages", :agent_file => agent_file, :config => {:libdir => libdir}).plugin
    # @agent.stubs(:require).with('puppet').returns(true)
  end

  describe "#meta" do
    it "should have valid metadata", :disabled => true do
      @agent.should have_valid_metadata
    end
  end

  describe "#do_packages_action" do
    before do
      logger = mock
      logger.stubs(:log)
      logger.stubs(:start)

      @plugin = mock
      @puppet_type = mock
      @puppet_service = mock
      @puppet_provider = mock

      MCollective::Log.configure(logger)
    end

    it "should succeed when action is uptodate and packages list is empty" do
      @agent.config.expects(:pluginconf).times(3).returns(@plugin)

      result = @agent.call("uptodate", :packages => [])
      result.should be_successful
      result.should have_data_items({"status" => 0, :packages => []})
    end

    it "should fail when action is uptodate and package has release, but not version" do
      @agent.config.expects(:pluginconf).times(3).returns(@plugin)
      packages = [{ "name" => "foo", "version" => nil, "release" => "23" }]

      result = @agent.call("uptodate", :packages => packages)
      result[:statuscode].should == 5
    end

    it "should succeed when action is uptodate and package is already installed - bzip2" do
      @agent.config.expects(:pluginconf).times(3).returns(@plugin)
      packages_request = [{ "name" => "bzip2", "version" => nil, "release" => nil }]
      packages_reply   = [{ "name" => "bzip2", "version" => "1.0.6", "release" => "1", "status" => 0, "tries" => 1 }]

      result = @agent.call("uptodate", :packages => packages_request)
      result.should be_successful
      result.should have_data_items({"status" => 0, :packages => packages_reply})
    end

    it "should succeed when action is uptodate and a package is installed - testtool" do
      pkg_install "testtool"

      @agent.config.expects(:pluginconf).times(3).returns(@plugin)
      packages_request = [{ "name" => "testtool", "version" => nil, "release" => nil }]
      packages_reply   = [{ "name" => "testtool", "version" => "1.3.0", "release" => "23", "status" => 0, "tries" => 1 }]

      result = @agent.call("uptodate", :packages => packages_request)
      result.should be_successful
      result.should have_data_items({"status" => 0, :packages => packages_reply})
    end

    it "should succeed when action is uptodate and a package is upgraded - test-ws-1.0 - r1111 -> r3333" do
      pkg_remove  "test-ws-1.0"
      pkg_install "test-ws-1.0", "0.1.0SNAPSHOT-1111"

      @agent.config.expects(:pluginconf).times(3).returns(@plugin)
      packages_request = [{ "name" => "test-ws-1.0", "version" => nil, "release" => nil }]
      packages_reply   = [{ "name" => "test-ws-1.0", "version" => "0.1.0SNAPSHOT", "release" => "3333", "status" => 0, "tries" => 1 }]

      result = @agent.call("uptodate", :packages => packages_request)
      result.should be_successful
      result.should have_data_items({"status" => 0, :packages => packages_reply})
    end

    it "should succeed when action is uptodate and a package is partial upgraded - test-ws-1.0 - r1111 -> r2222" do
      pkg_remove  "test-ws-1.0"
      pkg_install "test-ws-1.0", "0.1.0SNAPSHOT-1111"

      @agent.config.expects(:pluginconf).times(3).returns(@plugin)
      packages_request = [{ "name" => "test-ws-1.0", "version" => "0.1.0SNAPSHOT", "release" => "2222" }]
      packages_reply   = [{ "name" => "test-ws-1.0", "version" => "0.1.0SNAPSHOT", "release" => "2222", "status" => 0, "tries" => 1 }]

      result = @agent.call("uptodate", :packages => packages_request)
      result.should be_successful
      result.should have_data_items({"status" => 0, :packages => packages_reply})
    end

    it "should succeed when action is uptodate and a package is downgraded - test-ws-1.0 - r3333 -> r1111" do
      pkg_remove  "test-ws-1.0"
      pkg_install "test-ws-1.0", "0.1.0SNAPSHOT-3333"

      @agent.config.expects(:pluginconf).times(3).returns(@plugin)
      packages_request = [{ "name" => "test-ws-1.0", "version" => "0.1.0SNAPSHOT", "release" => "1111" }]
      packages_reply   = [{ "name" => "test-ws-1.0", "version" => "0.1.0SNAPSHOT", "release" => "1111", "status" => 0, "tries" => 1 }]

      result = @agent.call("uptodate", :packages => packages_request)
      result.should be_successful
      result.should have_data_items({"status" => 0, :packages => packages_reply})
    end

    it "should succeed when action is uptodate and a package is partially downgraded - test-ws-1.0 - r3333 -> r2222" do
      pkg_remove  "test-ws-1.0"
      pkg_install "test-ws-1.0", "0.1.0SNAPSHOT-3333"

      @agent.config.expects(:pluginconf).times(3).returns(@plugin)
      packages_request = [{ "name" => "test-ws-1.0", "version" => "0.1.0SNAPSHOT", "release" => "2222" }]
      packages_reply   = [{ "name" => "test-ws-1.0", "version" => "0.1.0SNAPSHOT", "release" => "2222", "status" => 0, "tries" => 1 }]

      result = @agent.call("uptodate", :packages => packages_request)
      result.should be_successful
      result.should have_data_items({"status" => 0, :packages => packages_reply})
    end

    it "should succeed when action is uptodate and a package is partially downgraded - test-ws-1.0 - r2222 -> r1111" do
      pkg_remove  "test-ws-1.0"
      pkg_install "test-ws-1.0", "0.1.0SNAPSHOT-2222"

      @agent.config.expects(:pluginconf).times(3).returns(@plugin)
      packages_request = [{ "name" => "test-ws-1.0", "version" => "0.1.0SNAPSHOT", "release" => "1111" }]
      packages_reply   = [{ "name" => "test-ws-1.0", "version" => "0.1.0SNAPSHOT", "release" => "1111", "status" => 0, "tries" => 1 }]

      result = @agent.call("uptodate", :packages => packages_request)
      result.should be_successful
      result.should have_data_items({"status" => 0, :packages => packages_reply})
    end

    it "should report failures when action is uptodate and one package is not available" do
      pkg_remove "testtool"

      @agent.config.expects(:pluginconf).times(3).returns(@plugin)
      packages_request = [{ "name" => "testtool",         "version" => nil, "release" => nil },
                          { "name" => "testdoesnotexist", "version" => nil, "release" => nil }]
      packages_reply   = [{ "name" => "testtool",         "version" => "1.3.0", "release" => "23", "status" => 0, "tries" => 1 },
                          { "name" => "testdoesnotexist", "version" => nil,     "release" => nil,  "status" => 1, "tries" => 3 }]

      result = @agent.call("uptodate", :packages => packages_request)
      result.should be_successful
      result.should have_data_items({"status" => 1, :packages => packages_reply})
    end

    it "should report success when action is uptodate and one package is given with version" do
      pkg_remove "testtool"

      @agent.config.expects(:pluginconf).times(3).returns(@plugin)
      packages_request = [{ "name" => "testtool",    "version" => "1.3.0",         "release" => "23" },
                          { "name" => "test-ws-1.0", "version" => nil,             "release" => nil }]
      packages_reply   = [{ "name" => "testtool",    "version" => "1.3.0",         "release" => "23",   "status" => 0, "tries" => 1 },
                          { "name" => "test-ws-1.0", "version" => "0.1.0SNAPSHOT", "release" => "3333", "status" => 0, "tries" => 1 }]

      result = @agent.call("uptodate", :packages => packages_request)
      result.should be_successful
      result.should have_data_items({"status" => 0, :packages => packages_reply})
    end

    it "should report failure when action is uptodate and the package is not available in the requested version - package not installed" do
      pkg_remove "testtool"

      @agent.config.expects(:pluginconf).times(3).returns(@plugin)
      packages_request = [{ "name" => "testtool", "version" => "1.4.0", "release" => "23" }]
      packages_reply   = [{ "name" => "testtool", "version" => nil,     "release" => nil,        "status" => 1, "tries" => 3 }]

      result = @agent.call("uptodate", :packages => packages_request)
      result.should be_successful
      result.should have_data_items({"status" => 1, :packages => packages_reply})
    end

    it "should report failure when action is uptodate and the package is not available in the requested version - package is installed" do
      pkg_remove  "test-ws-1.0"
      pkg_install "test-ws-1.0", "0.1.0SNAPSHOT-2222"

      @agent.config.expects(:pluginconf).times(3).returns(@plugin)
      packages_request = [{ "name" => "test-ws-1.0", "version" => "0.1.0SNAPSHOT", "release" => "4444" }]
      packages_reply   = [{ "name" => "test-ws-1.0", "version" => "0.1.0SNAPSHOT", "release" => "2222", "status" => 1, "tries" => 3 }]

      result = @agent.call("uptodate", :packages => packages_request)
      result.should be_successful
      result.should have_data_items({"status" => 1, :packages => packages_reply})
    end
  end
end
