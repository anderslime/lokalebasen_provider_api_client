module LokalebasenApi
  module Resource
    class Base

      protected

      def checked_response(response)
        case response.status
          when (400..499) then (fail "Error occured -> #{response.data.message}")
          when (500..599) then (fail "Server error -> #{error_msg(response)}")
        end
        yield response if block_given?
      end

      def add_method(relation, method)
        relation.instance_variable_get(:@available_methods).add(method)
        relation
      end

      def error_msg(response)
        if response.data.index("html")
          "Server returned HTML in error"
        else
          response.data
        end
      end
    end
  end
end
