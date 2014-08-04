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

    def add_credentials(username, password)
      user_agent.keychain.add(url, username, password)
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

    def affordance_type(method)
      case method.downcase
      when "get"
        "Navigate"
      when "post"
        "Create"
      when "put"
        "Update"
      when "delete"
        "Destroy"
      else
        method #allow passthrough
      end
    end


    def grant_list(creds)
      vars = { :username => creds.user.to_s }
      template = Addressable::Template.new(grant_list_pattern)
      grant_list_url = template.expand(vars)
      response = graph_transfer.make_request("GET", grant_list_url, nil)
      if response.status == 200
        response.graph.query(:predicate => Graph::Af.grants).map do |stmt|
          stmt.object
        end
      end
    end

    def grant_in_list(url, creds)
      list = grant_list(creds)
      return false if list.nil?
      return list.include?(url)
    end

    def have_grant?(url)
      creds = user_agent.keychain.credentials(url)
      if grant_list_pattern.nil? or creds.nil?
        response = graph_transfer.make_request("GET", url, nil)
        case response.status
        when 200
          return true
        when 401
          query = ::RDF::Query.new do
            pattern [:af, ::RDF.type, Graph::Af.Navigate]
            pattern [:af, Graph::Af.target, :pnode]
            pattern [:pnode, Graph::Af.pattern, :pattern]
          end
          response.graph.query(query) do |solution|
            self.grant_list_pattern = solution[:pattern].value
          end
          grant_in_list(url, creds) unless grant_list_pattern.nil?
        end
      else
        grant_in_list(url, creds)
      end
    rescue HTTP::Retryable
      false
    end

    def forbidden?(method, focus)
      graph = SourceRigor::RetrieveManager.new
      graph.rigor = source_rigor
      graph.source_graph = focus.access_manager.source_graph

      resource = focus.subject

      annealer = SourceRigor::CredenceAnnealer.new(graph.source_graph)
      af_type = affordance_type(method)
      query = SourceRigor::ResourceQuery.new([], {:subject_context => resource}) do
        pattern [:aff, Graph::Af.target, resource]
        pattern [:aff, ::RDF.type, Graph::Af[af_type]]
        pattern [:aff, Graph::Af.authorizedBy, :authz]
      end
      permissions = []
      annealer.resolve do
        permissions.clear
        graph.query(query) do |solution|
          permissions << solution[:authz]
        end
      end

      return false if permissions.empty?
      permissions.each do |grant|
        return false if have_grant?(grant)
      end
      return true
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
