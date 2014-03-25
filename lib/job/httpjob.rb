
require 'uri'

require 'job/job'

class HttpJob < Job

  def withHttpSession( host_url, &block )
    host_uri = URI( host_url )

    @http = Net::HTTP.new( host_uri.hostname, host_uri.port )
    if( host_uri.scheme == 'https' )
      @http.use_ssl = true
      @http.ssl_version = :SSLv3
    end
    @http.set_debug_output( $stdout ) if $DEBUG

    @http.start { yield }
  end

  def handleRequest( request, user, pass, body, headers )
    headers.each_pair { |k,v| request[k] = v }
    request.basic_auth( user, pass )
    request.body = body unless body.nil?

    @http.request( request )
  end

  def doRequest( request_type, url, user, pass, body = nil, headers = {} )
    uri = URI( url )
    req = request_type.new( uri )

    handleRequest( req, user, pass, body, headers )
  end

  def doGet( url, user, pass, body = nil, headers = {} )
    doRequest( Net::HTTP::Get, url, user, pass, body, headers )
  end

  def doPost( url, user, pass, body = nil, headers = {} )
    doRequest( Net::HTTP::Post, url, user, pass, body, headers )
  end

end
