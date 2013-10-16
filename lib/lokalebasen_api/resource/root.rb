module LokalebasenApi
  module Resource
    class Root
      attr_reader :agent

      def initialize(agent)
        @agent = agent
      end

      def get
        checked_response(agent.root) do |response|
          response.data
        end
      end

      def checked_response(response)
        case response.status
          when (400..499) then (fail "Error occured -> #{response.data.message}")
          when (500..599) then (fail "Server error -> #{error_msg(response)}")
        end
        yield response if block_given?
      end
    end
  end
end
