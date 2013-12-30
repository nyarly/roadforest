require 'roadforest/content-handling/type-handlers/rdfa-writer/render-environment'
module RoadForest::MediaType
  class RDFaWriter
    class PropertyEnvironment < RenderEnvironment
      attr_accessor :object_terms, :predicate, :inlist

      def yielded(item)
        @_engine.render(item)
      end

      def objects
        enum_for(:each_object)
      end

      def each_object
        object_terms.each do |term|
          env = @_engine.object_env(predicate, term)
          env.inlist = inlist
          #XXX Remove element=
          env.element = :li if object_terms.length > 1 || inlist
          yield(env)
        end
      end

      def object
        objects.first
      end

      def property
        get_curie(predicate)
      end

      def rel
        get_curie(predicate)
      end

      def template_kinds
        if objects.to_a.length > 1
          %w{property_values}
        else
          %w{property_value property_values}
        end
      end
    end
  end
end