require "lokalebasen_api/version"
require "lokalebasen_api/mapper/location"
require "lokalebasen_api/resource/base"
require "lokalebasen_api/resource/root"
require "lokalebasen_api/resource/location"
require "lokalebasen_api/client"
require "lokalebasen_api/location_client"

module LokalebasenApi
  def self.client(credentials, service_url)
    Client.new(credentials, service_url)
  end
end
