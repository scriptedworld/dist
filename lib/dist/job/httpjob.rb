
require 'uri'

require 'dist/job/job'

module Dist

  class HttpJob < Job

    def with_http_session( host_url, &block )
      host_uri = URI( host_url )

      @http = Net::HTTP.new( host_uri.hostname, host_uri.port )
      if host_uri.scheme == 'https'
        @http.use_ssl = true
        @http.ssl_version = :SSLv3
      end
      @http.set_debug_output( $stdout ) if $DEBUG

      @http.start { yield }
    end

    def handle_request( request, user, pass, body, headers )
      headers.each_pair { |k, v| request[k] = v }
      request.basic_auth( user, pass )
      request.body = body unless body.nil?

      @http.request( request )
    end

    def do_request( request_type, url, user, pass, body = nil, headers = {} )
      uri = URI( url )
      req = request_type.new( uri )

      handle_request( req, user, pass, body, headers )
    end

    def do_get( url, user, pass, body = nil, headers = {} )
      do_request( Net::HTTP::Get, url, user, pass, body, headers )
    end

    def do_post( url, user, pass, body = nil, headers = {} )
      do_request( Net::HTTP::Post, url, user, pass, body, headers )
    end

  end

end
