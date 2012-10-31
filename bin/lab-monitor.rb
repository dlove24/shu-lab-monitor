#!/usr/bin/env ruby
#

###
### Configuration and Startup
###

# Add the project library
$LOAD_PATH << "../lib"

require 'webrick'

require 'net/ssh'
require 'net/sftp'

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

# Define the core IPv6 prefix and derived sub-nets
MASTER_PREFIX = "2001:8b0:1698:cf4"
MASTER_PREFIX_LENGTH = 60

# Derive the 16 sub-nets from the master prefix
@address_list = Array.new

16.times do |num|
  @address_list << MASTER_PREFIX + num.to_s(16) + '::1'
end

###
### Data Model. Holds the status of the various nodes
###

class HostState

  def initialize

  end

  def say_me
    return "There is hpo"
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