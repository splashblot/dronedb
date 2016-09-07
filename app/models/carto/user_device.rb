# encoding: utf-8

require_relative './carto_json_serializer'

module Carto
  class UserDevice < ActiveRecord::Base
    belongs_to :user
    serialize :devices, ::Carto::CartoJsonSymbolizerSerializer

    validates :user, presence: true
    validate  :only_valid_categories

    VALID_CATEGORIES = [:drone].freeze

    private

    def only_valid_categories
      notifications.keys.none? do |category|
        errors.add(:devices, "Invalid category: #{category}") unless VALID_CATEGORIES.include?(category)
      end
    end
  end
end
