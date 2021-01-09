class JiraUtil
  class Base
    def initialize(resource)
      resource_name = self.class.to_s.split('::').last.downcase
      instance_variable_set("@#{resource_name}", resource)

      @resource = resource
    end

    def method_missing(name, *args)
      @resource.public_send(name, *args)
    end
  end
end
