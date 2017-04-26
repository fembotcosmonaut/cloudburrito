require_relative 'patron'
require 'mongoid'

# Pool
# A class to mananage pools of patrons
class Pool
  include Mongoid::Document

  has_many :patrons

  field :name, type: String
  field :_id, type: String, default: ->{ name }
end
