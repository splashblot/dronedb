# coding: UTF-8

class DeviceGroup < Sequel::Model

  many_to_one :organization

end
