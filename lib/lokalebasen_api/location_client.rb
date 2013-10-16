module LokalebasenApi
  class LocationClient
    attr_reader :agent

    def initialize(agent)
      @agent  = agent
    end

    # Returns all locations for the current provider
    # @return [Array<Map>] all locations
    def locations
      location_resource.all.map do |location|
        Mapper::Location.new(location).mapify
      end
    end

    private

    def location_resource
      Resource::Location.new(root_resource)
    end

    def root_resource
      Resource::Root.new(agent).get
    end
  end
end
