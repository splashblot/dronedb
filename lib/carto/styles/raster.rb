# encoding: utf-8

require_relative './style.rb'
require_relative '../definition.rb'

module Carto::Styles
  class Raster < Style
    def initialize(definition: default_definition)
      super(definition)
    end

    def self.accepted_geometry_types
      ['raster', 'the_raster_webmercator']
    end

    def default_definition
      Carto::Definition.instance.load_from_file(CARTOGRAPHY_DEFINITION_LOCATION)[:simple][:point]
    end

    def self.raster_opacity
      ["raster-opacity: 1"]
    end

  end
end
