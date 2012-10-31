#!/usr/bin/env ruby
#

###
### Configuration and Startup
###

# Add the project library
$LOAD_PATH << "../lib"

require 'webrick'

require 'net/ssh'
require 'net/http'

require 'trollop'

require 'haml'

opts = Trollop::options do
  version "mikrotik_upload_key 0.1.0 (c) 2012 David Love <david@homeunix.org.uk>"

  banner <<-EOS
    Starts to monitor a dedicated sub-net, for known services and hosts. Not very flexible: used
    to help a class understand who is working (and who isn't).

    Usage:
           lab-monitor

  EOS
end

###
### Data Model. Holds the status of the various nodes
###

class HostState

  # Define the core IPv6 prefix and derived sub-nets
  MASTER_PREFIX = "2001:8b0:1698:cf4"
  MASTER_PREFIX_LENGTH = 60

  def initialize

    # Derive the 16 router sub-nets from the master prefix
    @router_list = Array.new
    @ping_result = Array.new
    @ssh_result = Array.new
    @www_result = Array.new

    16.times do |host|
      @router_list << MASTER_PREFIX + host.to_s(16) + '::1'

      # Ping all the hosts in the address list
      %x[ping -n -c 3 #{@router_list[host]}]
      @ping_result << ($? == 0)
      puts @router_list[host]
      puts @ping_result

      # Try to connect to each host using ssh
      begin
        Net::SSH.start(@router_list[host], 'user', :password => "silver", :timeout => 1) do |ssh|
          ssh.exec!("hostname")
        end
        @ssh_result << true
      rescue
        @ssh_result << false
      end

      # Try to connect to each host using http
      response = Net::HTTP.get(@router_list[host], '/index.html')
      @www_result << (not response.nil? and not response.empty?)
    end

  end

  def host_address(host_number)
    @router_list[host_number]
  end

  def ping_result(host_number)
    @ping_result[host_number]
  end

  def ssh_result(host_number)
    @ssh_result[host_number]
  end

  def www_result(host_number)
    @www_result[host_number]
  end

end

###
### Create the Monitor Serverlet
###

class SubNetMonitor < WEBrick::HTTPServlet::AbstractServlet

  def initialize(arg)
    # Read the standard template, and keep it in memory
    # to save file I/O
    @@master_template = File.read("../src/index.haml")
    @@host_state = HostState.new
  end

  def do_GET(request, response)
    status, content_type, body = do_stuff_with(request)

    response.status = status
    response['Content-Type'] = content_type
    response.body = body
  end

  def do_stuff_with(request)
    # Build the page from the monitor state, using the
    # standard template
    say_me = "A strange world"

    content = Haml::Engine.new(@@master_template, :format => :html5)

    # Send the page back to the caller
    page_text = content.render(@@host_state)
    puts page_text
    return 200, "text/html", page_text
  end

end

###
### Launch the web server
###

server = WEBrick::HTTPServer.new(:Port => 8000)
server.mount "/monitor", SubNetMonitor
trap "INT" do server.shutdown end
server.start
