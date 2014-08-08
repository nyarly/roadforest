require 'base64'
require 'addressable/uri'

module RoadForest
  module HTTP
    class BasicCredentials < Struct.new(:user, :secret)
      def header_value
        "Basic #{Base64.strict_encode64("#{user}:#{secret}")}"
      end
    end
    YAML.add_tag("!basic", BasicCredentials)

    class CredentialSource
      def canonical_root(url)
        url = Addressable::URI.parse(url)
        url.path = "/"
        url.to_s
      end

      # @returns {BasicCredentials}
      # @returns nil to indicate no further credentials available
      def respond_to_challenge(url, realm, attempt)
        nil
      end
    end

    class PreparedCredentialSource < CredentialSource
      def initialize
        @for_url = Hash.new{|h,k| h[k] = []}
      end

      def add(url, user, secret)
        creds = BasicCredentials.new(user, secret)
        add_credentials(url, creds)
      end

      def add_credentials(url, creds)
        @for_url[canonical_root(url)] << creds
      end

      def respond_to_challenge(url, realm, attempt)
        @for_url[canonical_root(url)].fetch(attempt)
      rescue IndexError
        nil
      end
    end

    #Manages user credentials for HTTP Basic auth
    class Keychain
      ATTEMPT_LIMIT = 5
      def initialize
        @realm_for_url = {}
        @with_realm = {}
        @sources = []
        @source_enums = Hash.new{|h,k| @sources.each}
        @attempt_enums = Hash.new{|h,k| (0...ATTEMPT_LIMIT).each}
      end

      def add_source(source)
        @sources << source
        @source_enums.clear
        @attempt_enums.clear
      end

      def canonical_root(url)
        url = Addressable::URI.parse(url)
        url.path = "/"
        url.fragment = nil
        url.query = nil
        url.to_s
      end

      def stripped_url(url)
        url = Addressable::URI.parse(url)
        url.fragment = nil
        url.query = nil
        url
      end

      BASIC_SCHEME = /basic\s+realm=(?<q>['"])(?<realm>(?:(?!['"]).)*)\k<q>/i

      def challenge_response(url, challenge)
        url = stripped_url(url).to_s
        #Future note: the RFC means that the creds selection mechanics are
        #valid for all HTTP WWW-Authenticate reponses
        if (match = BASIC_SCHEME.match(challenge)).nil?
          return nil
        end
        realm = match[:realm]
        @realm_for_url[url] = realm

        cached_response(canonical_root(url), realm) || missing_credentials(url, realm)
      end

      def preemptive_response(url)
        realm = realm_for_url(url)
        url = canonical_root(url)
        return cached_response(url, realm)
      end

      def cached_response(url, realm)
        creds = credentials(url, realm)
        return nil if creds.nil?
        return creds.header_value
      end

      def credentials_for(url)
        realm = realm_for_url(url)
        url = canonical_root(url)
        credentials(url, realm)
      end

      def credentials(url, realm = nil)
        @with_realm[[url, realm]]
      end

      def missing_credentials(url, realm)
        loop do
          attempt = next_attempt(url, realm)
          creds = current_source(url, realm).respond_to_challenge(url, realm, attempt)
          if creds.nil?
            next_source(url, realm)
          else
            @with_realm[[canonical_root(url), realm]] = creds
            return creds.header_value
          end
        end
        return nil
      rescue StopIteration
        nil
      end

      def forget(url, realm)
        @with_realm.delete([url, realm])
      end

      def current_source(url, realm)
        @source_enums[[url, realm]].peek
      end

      def next_source(url, realm)
        @attempt_enums.delete([url, realm])
        @source_enums[[url, realm]].next
      rescue StopIteration
        @source_enums.delete([url, realm])
        raise
      end

      def next_attempt(url, realm)
        @attempt_enums[[url, realm]].next
      rescue StopIteration
        next_source(url, realm)
        retry
      end

      def realm_for_url(url)
        url = stripped_url(url)
        while (realm = @realm_for_url[url.to_s]).nil?
          new_url = url.join("..")
          return realm if new_url == url
          url = new_url
        end
        return realm || :default
      end
    end
  end
end
