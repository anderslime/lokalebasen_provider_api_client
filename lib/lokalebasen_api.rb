require "lokalebasen_api/version"
require "lokalebasen_api/mapper/location"
require "lokalebasen_api/client"

module LokalebasenApi
  def self.client(credentials, service_url)
    Client.new(credentials, service_url)
  end
end
