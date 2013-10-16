require 'map'

module LokalebasenApi
  module Mapper
    class Location
      attr_reader :resource

      def initialize(resource)
        @resource = resource
      end

      def mapify
        resource_to_map_object(resource)
      end

      private

      def resource_to_map_object(resource)
        res =  Map.new(resource)
        res.floor_plans = res.floor_plans.map {|fp| fp.to_hash } if res.has?(:floor_plans)
        res.photos = res.photos.map{|p| p.to_hash} if res.has?(:photos)
        res = Map.new(res.to_hash) # Minor hack
        res.resource = resource
        res
      end
    end
  end
end
