require_relative 'messenger'
require 'mongoid'

## Class to store data for the participants

class Patron
  include Mongoid::Document
  include Mongoid::Timestamps

  has_many :burritos, class_name: "Package", inverse_of: :hungry_man
  has_many :deliveries, class_name: "Package", inverse_of: :delivery_man
  has_many :request_loggers
  has_many :message_loggers

  field :user_id, type: String
  field :_id, type: String, default: ->{ user_id }
  field :is_active, type: Boolean, default: false
  field :last_time_activated, type: Time, default: ->{ Time.now }
  field :force_not_greedy, type: Boolean, default: false
  field :force_not_sleeping, type: Boolean, default: false
  field :user_token, type: String, default: ->{ rand(1<<256).to_s(36) }
  field :sleepy_time, type: Integer, default: 3600
  field :greedy_time, type: Integer, default: 3600
  field :slack_user,  type: Boolean, default: true

  def to_s
    "<@#{user_id}>"
  end

  def active!
    self.last_time_activated = Time.now
    self.is_active = true
    self.save
  end

  def active?
    self.is_active
  end

  def active_delivery
    deliveries.where({failed: false, received: false}).last
  end

  def is_on_delivery?
    active_delivery != nil
  end

  def incoming_burrito
    burritos.where({failed: false, received: false}).last
  end

  def is_waiting?
    incoming_burrito != nil
  end

  def time_of_last_burrito
    return last_time_activated unless burritos.where(received: true).exists?
    x = last_time_activated
    y = burritos.where(received: true).last.delivery_time
    x > y ? x : y
  end

  def time_of_last_delivery
    return 0 unless deliveries.where(received: true).exists?
    deliveries.where(received: true).last.delivery_time
  end

  def is_greedy?
    return false if force_not_greedy
    time_until_hungry > 0
  end

  def is_sleeping?
    return false if force_not_sleeping
    time_until_awake > 0
  end

  def time_until_hungry
    x = greedy_time - (Time.now - time_of_last_burrito).to_i
    x > 0 ? x : 0
  end

  def time_until_awake
    x = sleepy_time - (Time.now - time_of_last_delivery).to_i
    x > 0 ? x : 0
  end

  def new_token
    rand(1<<256).to_s(36)
  end

  def reset_token
    self.user_token = new_token
    self.save
  end

  def stats_url
    reset_token
    "https://cloudburrito.us/user?user_id=#{_id}&token=#{user_token}"
  end

  def slack_user_info
    return nil unless slack_user
    Messenger.user_info(self)
  end

  def name
    x = slack_user_info
    return x.user.profile.first_name unless x.nil?
    user_id
  end

  def slack_link
    "<@#{user_id}>"
  end
end
