require 'roadforest/content-handling/engine'

module RoadForest
  module ContentHandling
    class << self
      def rdf_engine
        @rdf_engine ||=
          begin
            require 'roadforest/content-handling/type-handlers/jsonld'
            require 'roadforest/content-handling/type-handlers/rdfa'
            rdfa = RoadForest::MediaType::Handlers::RDFa.new
            jsonld = RoadForest::MediaType::Handlers::JSONLD.new

            ContentHandling::Engine.new.tap do |engine|
              engine.add rdfa, "text/html;q=1;rdfa=1"
              engine.add rdfa, "application/xhtml+xml;q=1;rdfa=1"
              engine.add jsonld, "application/ld+json"
              engine.add rdfa, "text/html;q=0.5"
              engine.add rdfa, "application/xhtml+xml;q=0.5"
            end
          end
      end

      def plaintext_engine
        @plaintext_engine ||=
          begin
            require 'roadforest/content-handling/type-handler'
            text = RoadForest::MediaType::Handlers::Handler.new

            ContentHandling::Engine.new.tap do |engine|
              engine.add text, "text/plain"
            end
          end
      end

      # @warning This is only the most nebulous beginning of image handling
      def images_engine
        @image_engine ||=
          begin
            require 'roadforest/content-handling/type-handler'
            data = RoadForest::MediaType::Handlers::Handler.new

            RoadForest::ContentHandling::Engine.new.tap do |engine|
              engine.add data, "image/jpeg"
              engine.add data, "image/png;q=0.9"
              engine.add data, "image/gif;q=0.7"
            end
          end
      end

      # @warning This is only the most nebulous beginning of image handling
      def graphics_engine
        @graphics_engine ||=
          begin
            require 'roadforest/content-handling/type-handler'
            data = RoadForest::MediaType::Handlers::Handler.new

            RoadForest::ContentHandling::Engine.new.tap do |engine|
              engine.add data, "image/png"
              engine.add data, "image/gif;q=0.9"
              engine.add data, "image/jpeg;q=0.7"
            end
          end
      end
    end
  end
end
