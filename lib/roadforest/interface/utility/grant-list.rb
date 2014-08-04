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
        perm_route = nil
        begin
          perm_route = path_provider.route_for_name(:perm)
        rescue KeyError
        end
        start_focus do |focus|
          data.each do |grant|
            if perm_route.nil?
              focus.add(:af, :grants,  grant)
            else
              focus.add(:af, :grants,  path_provider.url_for(:perm, {:grant_name => grant}))
            end
          end
        end
      end
    end
  end
end
