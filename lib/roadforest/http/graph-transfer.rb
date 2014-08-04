require 'roadforest/http'
require 'roadforest/content-handling/common-engines'

module RoadForest
  module HTTP
    class GraphTransfer
      attr_writer :type_handling
      attr_accessor :user_agent, :trace

      def initialize(user_agent)
        @trace = false
        @user_agent = user_agent
        @type_preferences = Hash.new{|h,k| k.nil? ? "*/*" : h[nil]}
      end

      def put(url, graph)
        make_request("PUT", url, graph)
      end

      def get(url)
        make_request("GET", url)
      end

      def post(url, graph)
        make_request("POST", url, graph)
      end

      def make_request(method, url, graph, retry_limit=5)
        headers = {"Accept" => type_handling.parsers.types.accept_header}
        body = nil

        trace_graph("OUT", graph)

        if(%w{POST PUT PATCH}.include? method.upcase)
          content_type = best_type_for(url)
          renderer = type_handling.choose_renderer(content_type)
          headers["Content-Type"] = renderer.content_type_header
          body = renderer.from_graph(url, graph)
        end

        response = user_agent.make_request(method, url, headers, body, retry_limit)

        case response.status
        when 415 #Type not accepted
          record_accept_header(url, response.headers["Accept"])
          raise Retryable
        end

        build_response(url, response)
      rescue Retryable
        raise unless (retry_limit -= 1) > 0
        retry
      end

      def trace_graph(tag, graph)
        return unless @trace
        require 'rdf/turtle'
        @trace = $stderr unless @trace.respond_to?(:puts)
        @trace.puts "<#{tag}"
        if graph.respond_to?(:dump)
          @trace.puts graph.dump(:ntriples, :standard_prefixes => true, :prefixes => { "af" => "http://judsonlester.info/affordance#"})
        end
        @trace.puts "#{tag}>"
      end

      def type_handling
        @type_handling || ContentHandling.rdf_engine
      end

      def best_type_for(url)
        return @type_preferences[url]
      end

      def record_accept_header(url, types)
        return if types.nil? or types.empty?
        @type_preferences[nil] = types
        @type_preferences[url] = types
      end

      def build_response(url, response)
        parser = type_handling.choose_parser(response.headers["Content-Type"])
        graph = parser.to_graph(url, response.body_string)

        trace_graph("IN", graph)

        response = GraphResponse.new(url, response)
        response.graph = graph
        return response
      rescue ContentHandling::UnrecognizedType
        puts "\n#{__FILE__}:#{__LINE__} => #{response.inspect}"
        return UnparseableResponse.new(url, response)
      end
    end
  end
end
