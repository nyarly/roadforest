require 'base64'
require 'addressable/uri'

module RoadForest
  module HTTP
    #Manages user credentials for HTTP Basic auth
    class Keychain
      class Credentials < Struct.new(:user, :secret)
        def header_value
          "Basic #{Base64.strict_encode64("#{user}:#{secret}")}"
        end
      end

      def initialize
        @realm_for_url = {}
        @with_realm = {}
      end

      def add(url, user, secret, realm=nil)
        creds = Credentials.new(user, secret)
        add_credentials(url, creds, realm || :default)
      end

      def add_credentials(url, creds, realm)
        url = url.to_s.dup
        if url[-1] != "/"
          url << "/"
        end
        @realm_for_url[url] = realm

        url = Addressable::URI.parse(url)
        url.path = "/"
        @with_realm[[url.to_s,realm]] = creds
      end

      BASIC_SCHEME = /basic\s+realm=(?<q>['"])(?<realm>(?:(?!['"]).)*)\k<q>/i

      def challenge_response(url, challenge)
        if (match = BASIC_SCHEME.match(challenge)).nil?
          return nil
        end
        realm = match[:realm]

        response(url, realm)
      end

      def credentials(url, realm = nil)
        lookup_url = Addressable::URI.parse(url)
        lookup_url.path = "/"
        lookup_url = lookup_url.to_s
        realm ||= realm_for_url(url)
        creds = @with_realm[[lookup_url,realm]] || @with_realm[[lookup_url, :default]]
        if creds.nil? and not realm.nil?
          creds = missing_credentials(url, realm)
          unless creds.nil?
            add_credentials(url, creds, realm)
          end
        end
        creds
      end

      def response(url, realm)
        creds = credentials(url, realm)
        return nil if creds.nil?

        return creds.header_value
      end

      def missing_credentials(url, realm)
        nil
      end

      def realm_for_url(url)
        while (realm = @realm_for_url[url.to_s]).nil?
          new_url = url.join("..")
          return realm if new_url == url
          url = new_url
        end
        return :default
      end

      def preemptive_response(url)
        url = Addressable::URI.parse(url)
        realm = realm_for_url(url)

        return response(url, realm)
      end
    end
  end
end
