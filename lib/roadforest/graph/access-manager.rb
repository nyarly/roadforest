require 'rdf'
require 'roadforest/graph/normalization'

module RoadForest::Graph
  class ReadOnlyManager
    include ::RDF::Countable
    include ::RDF::Enumerable
    include ::RDF::Queryable
    include Normalization

    attr_accessor :resource, :source_graph

    def resource=(resource)
      @resource = normalize_context(resource)
    end

    def reset
    end

    def dup
      other = self.class.allocate
      other.resource = self.resource
      other.source_graph = self.source_graph

      return other
    end

    alias origin_graph source_graph
    alias destination_graph source_graph

    def relevant_prefixes
      relevant_prefixes_for_graph(origin_graph)
    end

    def each_statement(&block)
      origin_graph.each_statement(&block)
    end

    def each(&block)
      origin_graph.each(&block)
    end

    def build_query
      ::RDF::Query.new([], {}) do |query|
        yield query
      end
    end

    def query_execute(query, &block)
      execute_search(query, &block)
    end

    def query_pattern(pattern, &block)
      execute_search(pattern, &block)
    end

    def execute_search(search, &block)
      search.execute(origin_graph, &block)
    end
  end

  class WriteManager < ReadOnlyManager
    include ::RDF::Writable

    def insert(statement)
      destination_graph.insert(statement)
    end

    def insert_statement(statement)
      destination_graph.insert(statement)
    end

    def delete(statement)
      statement = RDF::Query::Pattern.from(statement)
      destination_graph.delete(statement)
    end
  end

  class SplitManager < WriteManager
    attr_accessor :target_graph

    alias destination_graph target_graph

    def reset
      @target_graph ||= ::RDF::Repository.new
      @target_graph.clear
    end

    def dup
      other = super
      other.target_graph = self.target_graph
      return other
    end

    def relevant_prefixes
      super.merge(relevant_prefixes_for_graph(destination_graph))
    end

    def each_target
      destination_graph.each_context do |context|
        graph = ::RDF::Graph.new(context, :data => target_graph)
        yield(context, graph)
      end
    end
  end

  class CopyManager < SplitManager
    def execute_search(search, &block)
      super(search) do |statement|
        destination_graph.insert(statement)
        yield statement
      end
    end
  end
end
