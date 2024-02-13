require 'json'

# this class takes 

class Response
  def initialize(json_str)
    @data = JSON.parse(json_str)
    create_methods_for_keys
  end

  def responseParameters
    @data.keys
  end

  private

  def create_methods_for_keys
    @data.each { |k, v| define_singleton_method(k, -> { v }) }
  end
end

