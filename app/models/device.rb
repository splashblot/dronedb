# coding: UTF-8

# This class currently doesn't serve any purpose except pure data storage
class Device < Sequel::Model
  # Ignore mass-asigment on not allowed columns
  self.strict_param_setting = false

  set_allowed_columns(:devices)

  def validate
    super
    errors.add(:devices, "can't be blank") if name.blank?
  end
end
