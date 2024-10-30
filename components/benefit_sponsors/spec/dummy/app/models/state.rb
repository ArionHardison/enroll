# frozen_string_literal: true

# Model for storing the names and IDs of US states and legal territories.
class State
  include Mongoid::Document

  STATE_LIST = [
    ["Alabama", "AL"],
    ["Alaska", "AK"],
    ["American Samoa", "AS"],
    ["Arizona", "AZ"],
    ["Arkansas", "AR"],
    ["California", "CA"],
    ["Colorado", "CO"],
    ["Connecticut", "CT"],
    ["Delaware", "DE"],
    ["District of Columbia", "DC"],
    ["Florida", "FL"],
    ["Georgia", "GA"],
    ["Guam", "GU"],
    ["Hawaii", "HI"],
    ["Idaho", "ID"],
    ["Illinois", "IL"],
    ["Indiana", "IN"],
    ["Iowa", "IA"],
    ["Kansas", "KS"],
    ["Kentucky", "KY"],
    ["Louisiana", "LA"],
    ["Maine", "ME"],
    ["Maryland", "MD"],
    ["Massachusetts", "MA"],
    ["Michigan", "MI"],
    ["Minnesota", "MN"],
    ["Mississippi", "MS"],
    ["Missouri", "MO"],
    ["Montana", "MT"],
    ["Northern Mariana Islands", "MP"],
    ["Nebraska", "NE"],
    ["Nevada", "NV"],
    ["New Hampshire", "NH"],
    ["New Jersey", "NJ"],
    ["New Mexico", "NM"],
    ["New York", "NY"],
    ["North Carolina", "NC"],
    ["North Dakota", "ND"],
    ["Ohio", "OH"],
    ["Oklahoma", "OK"],
    ["Oregon", "OR"],
    ["Pennsylvania", "PA"],
    ["Puerto Rico", "PR"],
    ["Rhode Island", "RI"],
    ["South Carolina", "SC"],
    ["South Dakota", "SD"],
    ["Tennessee", "TN"],
    ["Texas", "TX"],
    ["Utah", "UT"],
    ["Vermont", "VT"],
    ["Virginia", "VA"],
    ["U.S. Virgin Islands", "VI"],
    ["Washington", "WA"],
    ["West Virginia", "WV"],
    ["Wisconsin", "WI"],
    ["Wyoming", "WY"]
  ].freeze

  CLIENT_STATE = EnrollRegistry.feature_enabled?(:increase_state_client_prominence) ? [EnrollRegistry[:enroll_app].setting(:state_name).item, EnrollRegistry[:enroll_app].setting(:site_key).item.to_s.upcase].freeze : nil
  STATE_IDS = STATE_LIST.dup.map(&:last).sort.unshift(CLIENT_STATE&.last).compact.freeze
  NAMES_AND_IDS = STATE_LIST.dup.unshift(CLIENT_STATE).compact.freeze
end
