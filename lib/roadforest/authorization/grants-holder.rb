require 'roadforest/authorization/grant-builder'
module RoadForest
  module Authorization
    # Caches the obfuscated tokens used to identify permission grants
    class GrantsHolder
      def initialize(salt, hash_function)
        digester = OpenSSL::HMAC.new(salt, hash_function)
        @conceal = true
        @grants_cache = Hash.new do |h, k| #XXX potential resource exhaustion here - only accumulate auth'd results
          if conceal
            digester.reset
            digester << token_for(k)
            h[k] = digester.hexdigest
          else
            token_for(k)
          end
        end
      end
      attr_accessor :conceal

      #For use in URIs, per RFC3986:
      #Cannot use: ":/?#[]@!$&'()*+;="
      #Percent encoding uses %
      #Can use: ".,$^*_-|<>~`"
      #Grants are of the form [:name, [:key, value]*]
      def token_for(grant)
        name, attrs = *grant
        attrs = (attrs || []).map{|pair| group(pair, "_", "~")}
        percent_encode(group([name] + attrs, ".", "-"))
      end

      def group(list, sep, replace)
        list.map{|part| part.to_s.gsub(sep, replace)}.join(sep)
      end

      PERCENT_ENCODINGS = Hash.new do |h,k|
        h[k] = k.force_encoding("US-ASCII").getbyte(0).to_s(16)
      end

      def percent_encode(string)
        string.gsub(%r|[\[\]:/?#@!$&'()*+;=]|) do |match|
          PERCENT_ENCODINGS[match]
        end
      end

      def get(key)
        @grants_cache[key]
      end
      alias [] get

      def build_grants
        builder = GrantBuilder.new(self)
        yield builder
        return builder.list
      end
    end
  end
end
