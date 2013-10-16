module LokalebasenApi
  module Resource
    class Location < Base
      attr_reader :root_resource

      def initialize(root_resource)
        @root_resource = root_resource
      end

      def all
        location_list_resource_agent.locations
      end

      private

      def location_list_resource_agent
        checked_response(root_resource.rels[:locations].get) do |response|
          resource = response.data
          add_method(resource.rels[:self], :post)
          resource
        end
      end
    end
  end
end
