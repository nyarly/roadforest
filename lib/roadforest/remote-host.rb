require 'roadforest/source-rigor'
require 'roadforest/source-rigor/credence-annealer'
require 'roadforest/source-rigor/rigorous-access'
require 'roadforest/source-rigor/graph-store' #XXX
require 'roadforest/graph/graph-focus'
require 'roadforest/graph/post-focus'
require 'roadforest/http/user-agent'
require 'roadforest/http/graph-transfer'
require 'roadforest/http/adapters/excon'
require 'addressable/template'

module RoadForest
  # This is a client's main entry point in RoadForest - we instantiate a
  # RemoteHost to represent the server in the local program and interact with
  # it. The design goal is that, having created a RemoteHost object, you should
  # be able to forget that it isn't, in fact, part of your program. So, the
  # details of TCP (or indeed HTTP, or whatever the network is doing) become
  # incidental to the abstraction.
  #
  # One consequence being that you should be able to use a mock host for
  # testing.
  class RemoteHost
    include Graph::Normalization

    def initialize(well_known_url)
      self.url = well_known_url
    end
    attr_reader :url
    attr_accessor :grant_list_pattern
    attr_writer :http_client

    def url=(string)
      @url = normalize_resource(string)
    end

    def build_graph_store
      SourceRigor::GraphStore.new
    end

    def http_client
      @http_client ||= HTTP::ExconAdapter.new(url)
    end

    def http_trace=(target)
      user_agent.trace = target
    end
    alias trace= http_trace=

    def graph_trace=(target)
      graph_transfer.trace = target
    end

    def user_agent
      @user_agent ||= HTTP::UserAgent.new(http_client)
    end

    def graph_transfer
      @graph_transfer ||= HTTP::GraphTransfer.new(user_agent)
    end

    def use_ca_cert(cert)
      http_client.connection_defaults.merge!(:ssl_ca_file => cert)
      http_client.reset_connections
    end

    def use_client_tls(key, cert)
      http_client.connection_defaults.merge!(:client_key => key, :client_cert => cert)
      http_client.reset_connections
    end

    def prepared_credential_source
      @prepared_credential_source ||=
        HTTP::PreparedCredentialSource.new.tap do |prepd|
        user_agent.keychain.add_source(prepd)
        end
    end

    def add_credentials(username, password)
      prepared_credential_source.add(url, username, password)
    end

    def source_rigor
      @source_rigor ||=
        begin
          rigor = SourceRigor.http
          rigor.graph_transfer = graph_transfer
          rigor
        end
    end

    def render_graph(graph)
      Resource::ContentType::JSONLD.from_graph(graph)
    end

    def anneal(focus)
      graph = focus.access_manager.source_graph
      annealer = SourceRigor::CredenceAnnealer.new(graph)
      annealer.resolve do
        focus.reset
        yield focus
      end
    end

    class AuthorizationDecider
      include Graph::Normalization

      def initialize(remote_host, focus)
        @graph = SourceRigor::RetrieveManager.new
        graph.rigor = remote_host.source_rigor
        graph.source_graph = focus.access_manager.source_graph

        @resource = focus.subject
        @keychain = remote_host.user_agent.keychain
      end

      attr_reader :graph, :resource, :keychain, :grant_list_pattern

      def forbidden?(method)
        annealer = SourceRigor::CredenceAnnealer.new(graph.source_graph)

        permissions = []
        annealer.resolve do
          permissions.clear
          @grant_list_pattern = nil

          graph.query(authby_query(method)) do |solution|
            permissions << solution[:authz]
          end
          permissions.each do |grant|
            return false if have_grant?(grant)
          end
        end

        return false if permissions.empty?
        return true
      end

      def have_grant?(url)
        creds = keychain.credentials_for(url)
        if grant_list_pattern.nil? or creds.nil?
          direct_check(url)
        else
          grant_list(creds).include?(url)
        end
      end

      def direct_check(url)
        statements = graph.query(:subject => url)
        if !statements.empty?
          return true
        else
          annealer = SourceRigor::CredenceAnnealer.new(graph.source_graph)
          annealer.resolve do
            graph.query(list_pattern_query(url)) do |solution|
              @grant_list_pattern = solution[:pattern].value
            end
          end
          return false
        end
      end

      def grant_list(creds)
        return [] if grant_list_pattern.nil?
        template = Addressable::Template.new(grant_list_pattern)
        grant_list_url = uri(template.expand( :username => creds.user.to_s ).to_s)
        graph.query_resource_pattern(grant_list_url, :subject => grant_list_url, :predicate => Graph::Af.grants).map do |stmt|
          stmt.object
        end
      end

      def list_pattern_query(url)
        SourceRigor::ResourceQuery.new([], :subject_context => url) do
          pattern [:af, ::RDF.type, Graph::Af.Navigate]
          pattern [:af, Graph::Af.target, :pnode]
          pattern [:pnode, Graph::Af.pattern, :pattern]
        end
      end

      def affordance_type(method)
        case method.downcase
        when "get"
          Graph::Af.Navigate
        when "post"
          Graph::Af.Create
        when "put"
          Graph::Af.Update
        when "delete"
          Graph::Af.Destroy
        else
          Graph::Af[method] #allow passthrough
        end
      end

      def authby_query(method)
        af_type = affordance_type(method)
        resource = self.resource
        SourceRigor::ResourceQuery.new([], {:subject_context => resource}) do
          pattern [:aff, Graph::Af.target, resource]
          pattern [:aff, ::RDF.type, af_type]
          pattern [:aff, Graph::Af.authorizedBy, :authz]
        end
      end
    end

    def forbidden?(method, focus)
      decider = AuthorizationDecider.new(self, focus)

      decider.forbidden?(method)
    end

    def transaction(manager_class, focus_class, &block)
      graph = build_graph_store
      access = manager_class.new
      access.rigor = source_rigor
      access.source_graph = graph
      focus = focus_class.new(access, url)

      anneal(focus, &block)

      return focus
    end

    def putting(&block)
      update = transaction(SourceRigor::UpdateManager, Graph::GraphFocus, &block)

      access = update.access_manager

      access.each_target do |context, graph|
        graph_transfer.put(context, graph)
      end
    end

    def posting(&block)
      poster = transaction(SourceRigor::PostManager, Graph::PostFocus, &block)

      poster.graphs.each_pair do |url, graph|
        graph_transfer.post(url, graph)
      end
    end

    def getting(&block)
      transaction(SourceRigor::RetrieveManager, Graph::GraphFocus, &block)
    end

    def put_file(destination, type, io)
      if destination.respond_to?(:to_context)
        destination = destination.to_context
      elsif destination.respond_to?(:to_s)
        destination = destination.to_s
      end
      user_agent.make_request("PUT", destination, {"Content-Type" => type}, io)
    end

    #TODO:
    #def deleting
    #def patching
  end
end
