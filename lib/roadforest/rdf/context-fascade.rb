require 'rdf'
require 'roadforest/rdf/resource-query'
require 'roadforest/rdf/resource-pattern'

module RoadForest::RDF
  class ContextFascade
    include ::RDF::Countable
    include ::RDF::Enumerable
    include ::RDF::Queryable

    def initialize(store, resource, rigor)
      @store, @resource, @rigor = store, resource, rigor
    end

    def query_execute(query, &block)
      ResourceQuery.from(query, @resource, @rigor).execute(@store, &block)
    end

    def query_pattern(pattern, &block)
      ResourcePattern.from(pattern, {:context_roles => {:subject => @resource}, :source_rigor => @rigor}).execute(@store, &block)
    end

    def each(&block)
      @store.each(&block)
    end

    def insert(statement)
      @store.insert(statement)
    end

    def delete(statement)
      @store.delete(statement)
    end
  end
end
