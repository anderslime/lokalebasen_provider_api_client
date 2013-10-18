require "lokalebasen_api/version"
require "lokalebasen_api/resource/http_method_permissioning"
require "lokalebasen_api/resource/root"
require "lokalebasen_api/resource/location"
require "lokalebasen_api/resource/asset"
require "lokalebasen_api/resource/photo"
require "lokalebasen_api/resource/prospectus"
require "lokalebasen_api/resource/floor_plan"
require "lokalebasen_api/mapper/location"
require "lokalebasen_api/mapper/job"
require "lokalebasen_api/client_helper"
require "lokalebasen_api/client"
require "lokalebasen_api/response_checker"
require "lokalebasen_api/location_client"

module LokalebasenApi
  def self.client(credentials, service_url)
    Client.new(credentials, service_url)
  end
end
