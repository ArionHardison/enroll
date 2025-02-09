# frozen_string_literal: true

module EventLogs
  class MonitoredEvent
    include Mongoid::Document
    include Mongoid::Timestamps

    belongs_to :monitorable, polymorphic: true

    field :account_hbx_id, type: String
    filed :account_username, type: String
    field :subject_hbx_id, type: String
    field :event_category, type: Symbol
    field :event_time, type: DateTime
    field :login_session_id, type: String

    index({ account_hbx_id: 1 })
    index({ account_username: 1 })
    index({ subject_hbx_id: 1 })
    index({ event_category: 1 })
    index({ event_time: 1 })
    index({ login_session_id: 1 })
  end
end
