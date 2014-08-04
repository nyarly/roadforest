require 'roadforest/interface/rdf'

module RoadForest
  module Utility
    class GrantList < Interface::RDF
      def self.path_params
        [ :username ]
      end

      def required_grants(method)
        if method == "GET"
          services.authz.build_grants do |grants|
            grants.add(:is, :name => params[:username])
            grants.add(:admin)
          end
        else
          super
        end
      end

      def data
        entity = Authorization::AuthEntity.new
        entity.username = params[:username]
        services.authz.policy.grants_for(entity)
      end

      def new_graph
        start_focus do |focus|
          focus.add_list(:rdf, :value) do |list|
            data.each do |grant|
              list << grant
            end
          end
        end
      end
    end
  end
end
