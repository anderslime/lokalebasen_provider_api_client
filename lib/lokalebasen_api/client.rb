require 'json'
require 'sawyer'
require 'map'
require 'forwardable'
require_relative 'contact_client'

module LokalebasenApi
  class Client
    extend Forwardable

    def_delegators :location_client, :locations

    attr_reader :logger, :agent

    # @param credentials [Hash] e.g. { :api_key => "03e7ad6c157dcfd1195144623d06ad0d2498e9ec" }
    # @param enable_logging [Boolean] specifies wether the client should log calls
    # @param service_url [String] URL to root of service e.g. http://IP_ADDRESS:3000/api/provider
    def initialize(credentials, service_url, agent, logger = nil)
      @api_key = credentials[:api_key]
      @service_url = service_url
      @logger = logger
      @agent = agent || default_agent

      raise "api_key required" if @api_key.nil?
      raise "service_url required" if @service_url.nil?
    end

    # Returns all contacts for the current provider
    # @return [Array<Map>] all contacts
    def contacts
      contact_client.contacts
    end

    # Returns specified location for the current provider
    # @param location_ext_key [String] external_key for location guid e.g. "39PQ32KUC6BSC3AS"
    # @raise [RuntimeError] if location not found, e.g. "Location with external_key 'LOC_EXT_KEY', not found!"
    # @return [Map] location
    def location(location_ext_key)
      loc = location_res(location_ext_key)
      location_res_to_map(loc.location)
    end

    # Returns true if locations having location_ext_key exists
    # @param location_ext_key [String] external_key for location guid e.g. "39PQ32KUC6BSC3AS"
    # @return [Boolean] exists?
    def exists?(location_ext_key)
      locations.any?{ |location| location[:external_key] == location_ext_key }
    end

    # @param location [Hash] e.g. { :location => { :title => "" .. } }
    # @return [Map] created location
    def create_location(location)
      debug("create_location: #{location.inspect}")
      locs = locations_res.data
      rel = add_method(locs.rels[:self], :post)
      response = rel.post(location)
      check_response(response)
      location_res_to_map(response.data.location)
    end

    # @return [Map] updated location
    def update_location(location)
      debug("update_location: #{location.inspect}")
      loc_res = location_res(location["location"]["external_key"]).location
      rel = add_method(loc_res.rels[:self], :put)
      response = rel.put(location)
      check_response(response)
      location_res_to_map(response.data.location)
    end

    # Deactivates the specified location
    # @param location_ext_key [String] external_key for location guid e.g. "39PQ32KUC6BSC3AS"
    # @return [Map] location
    def deactivate(location_ext_key)
      debug("deactivate: #{location_ext_key}")
      response = set_state(:deactivation, location_res(location_ext_key).location) if can_be_deactivated?(location_ext_key)
      location_res_to_map(response.data.location) if response
    end

    # Activates the specified location
    # @param location_ext_key [String] external_key for location guid e.g. "39PQ32KUC6BSC3AS"
    # @return [Map] location
    def activate(location_ext_key)
      debug("activate: #{location_ext_key}")
      response = set_state(:activation, location_res(location_ext_key).location) if can_be_activated?(location_ext_key)
      location_res_to_map(response.data.location) if response
    end

    # Creates a photo create background job on the specified location
    # @return [Map] created job
    def create_photo(photo_url, photo_ext_key, location_ext_key)
      loc = location_res(location_ext_key).location
      rel = add_method(loc.rels[:photos], :post)
      response = rel.post(photo_data(photo_ext_key, photo_url))
      check_response(response)
      res = response.data.job.to_hash
      res[:url] = response.data.job.rels[:self].href_template
      Map.new(res)
    end

    # Deletes specified photo
    # @raise [RuntimeError] if Photo not found, e.g. "Photo with external_key 'PHOTO_EXT_KEY', not found!"
    # @return [void]
    def delete_photo(photo_ext_key, location_ext_key)
      delete_resource(photo(photo_ext_key, location_ext_key))
    end

    # Creates a prospectus create background job on the specified location
    # @return [Map] created job
    def create_prospectus(prospectus_url, prospectus_ext_key, location_ext_key)
      loc = location_res(location_ext_key).location
      rel = add_method(loc.rels[:prospectuses], :post)
      response = rel.post(prospectus_data(prospectus_ext_key, prospectus_url))
      check_response(response)
      res = response.data.job.to_hash
      res[:url] = response.data.job.rels[:self].href_template
      Map.new(res)
    end

    # Deletes specified floorplan
    # @raise [RuntimeError] if Floorplan not found, e.g. "Floorplan with external_key 'FLOORPLAN_EXT_KEY', not found!"
    # @return [void]
    def delete_prospectus(prospectus_ext_key, location_ext_key)
      delete_resource(prospectus(prospectus_ext_key, location_ext_key))
    end

    # Creates a floorplan create background job on the specified location
    # @return [Map] created job
    def create_floorplan(floorplan_url, floorplan_ext_key, location_ext_key)
      loc = location_res(location_ext_key).location
      rel = add_method(loc.rels[:floor_plans], :post)
      response = rel.post(floorplan_data(floorplan_ext_key, floorplan_url))
      check_response(response)
      res = response.data.job.to_hash
      res[:url] = response.data.job.rels[:self].href_template
      Map.new(res)
    end

    # Deletes specified floorplan
    # @raise [RuntimeError] if Floorplan not found, e.g. "Floorplan with external_key 'FLOORPLAN_EXT_KEY', not found!"
    # @return [void]
    def delete_floorplan(floorplan_ext_key, location_ext_key)
      delete_resource(floorplan(floorplan_ext_key, location_ext_key))
    end

    # Deletes specified resource
    # @return [void]
    def delete_resource(resource)
      rel = resource.rels[:self]
      add_method(rel, :delete)
      response = rel.delete
      check_response(response)
    end

    # Sets state on the resource, by calling post on relation defined by relation_type
    # E.g. set_state(:deactivation, location_resource) #=> location
    # @param relation_type [Symbol] state e.g. :deactivation
    # @param resource [Sawyer::Resource] the resource to set state on
    # @return [Sawyer::Resource] response
    def set_state(relation_type, resource)
      relation = add_method(resource.rels[relation_type], :post)
      response = relation.post
      check_response(response)
      response
    end

    private

      def location_client
        LokalebasenApi::LocationClient.new(agent)
      end

      def contact_client
        @contact_client ||= LokalebasenApi::ContactClient.new(agent)
      end

      def can_be_activated?(location_ext_key)
        loc = location_res(location_ext_key).location
        !loc.rels[:activation].nil?
      end

      def can_be_deactivated?(location_ext_key)
        loc = location_res(location_ext_key).location
        !loc.rels[:deactivation].nil?
      end

      def check_response(response)
        case response.status
          when (400..499) then (fail "Error occured -> #{response.data.message}")
          when (500..599) then (fail "Server error -> #{error_msg(response)}")
          else nil
        end
      end

      def error_msg(response)
        if response.data.index("html")
          "Server returned HTML in error"
        else
          data
        end
      end

      def location_res(location_ext_key)
        location = locations_res.data.locations.detect { |location| location.external_key == location_ext_key }
        raise NotFoundException.new("Location with external_key '#{location_ext_key}', not found!") if location.nil?
        location.rels[:self].get.data
      end

      def locations_res
        root = agent.start
        check_response(root)
        locations_rel = root.data.rels[:locations]
        locations_rel.get
      end

      def prospectus(prospectus_ext_key, location_ext_key)
        loc = location_res(location_ext_key)
        prospectus = loc.location.prospectus if loc.location.respond_to?(:prospectus) && loc.location.prospectus.external_key == prospectus_ext_key
        if prospectus.nil?
          raise NotFoundException.new, "Prospectus with external_key "\
            "'#{prospectus_ext_key}', not found on #{location_ext_key}!"
        end
        prospectus
      end

      def floorplan(floorplan_ext_key, location_ext_key)
        loc = location_res(location_ext_key)
        floorplan = loc.location.floor_plans.detect{|floorplan| floorplan.external_key == floorplan_ext_key }
        if floorplan.nil?
          raise NotFoundException, "Floorplan with external_key "\
            "'#{floorplan_ext_key}', not found on #{location_ext_key}!"
        end
        floorplan
      end

      def photo(photo_ext_key, location_ext_key)
        loc = location_res(location_ext_key)
        photo = loc.location.photos.detect{|photo| photo.external_key == photo_ext_key }
        if photo.nil?
          raise NotFoundException, "Photo with external_key "\
            "'#{photo_ext_key}', not found on #{location_ext_key}!"
        end
        photo
      end

      # PATCH: Because Lokalebasen API relations URLs do not include possible REST methods, Sawyer defaults to :get only.
      # This methods adds a REST method to the relation
      # @!visibility private
      # @param method [Symbol] - :put, :post, :delete
      # @return [Sawyer::Relation] patched relation
      def add_method(relation, method)
        relation.instance_variable_get(:@available_methods).add(method)
        relation
      end

      def default_agent
        Sawyer::Agent.new(service_url) do |http|
          http.headers['Content-Type'] = 'application/json'
          http.headers['Api-Key'] = @api_key
        end
      end

      def photo_data(photo_ext_key, photo_url)
        {
          photo: {
            external_key: photo_ext_key,
            url: photo_url
          }
        }
      end

      def floorplan_data(floorplan_ext_key, floorplan_url)
        {
          floor_plan: {
            external_key: floorplan_ext_key,
            url: floorplan_url
          }
        }
      end

      def prospectus_data(prospectus_ext_key, prospectus_url)
        {
          prospectus: {
            external_key: prospectus_ext_key,
            url: prospectus_url
          }
        }
      end

      def location_res_to_map(loc_res)
        res =  Map.new(loc_res)
        res.floor_plans = res.floor_plans.map{|fp| fp.to_hash} if res.has?(:floor_plans)
        res.photos = res.photos.map{|p| p.to_hash} if res.has?(:photos)
        res = Map.new(res.to_hash) # Minor hack
        res.resource = loc_res
        res
      end

      def service_url
        @service_url
      end

      def debug(message)
        if logger
          logger.debug("ProviderApiClient") { message }
        end
      end
  end

  class NotFoundException < StandardError
    def initialize(msg)
      super(msg)
    end
  end

end
