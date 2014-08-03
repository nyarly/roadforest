module RoadForest
  module Utility
    class Grant < Interface::RDF
      def path_params
        [ :grant_name ]
      end

      def required_grants(method)
        #except in the unlikely case that a grant hashes to "NSG"
        [ params[:grant_name] || "no_such_grant" ]
      end

      def data
        [ params[:grant_name] || "no_such_grant" ]
      end

      def new_graph
        ::RDF::Graph.new
      end
    end
  end
end
