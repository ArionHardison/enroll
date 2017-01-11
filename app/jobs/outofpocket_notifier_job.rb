class OutofpocketNotifierJob < ActiveJob::Base
  queue_as :default

  def perform(employer_profile_id)
    Resque.logger.level = Logger::DEBUG
    ep=EmployerProfile.find(employer_profile_id)
    event_kind = ApplicationEventKind.where(:event_name => 'out_of_pocker_url_notifier').first
    notice_trigger = event_kind.notice_triggers.first
    builder = notice_trigger.notice_builder.camelize.constantize.new(ep, {
              template: notice_trigger.notice_template,
              subject: event_kind.title,
              mpi_indicator: notice_trigger.mpi_indicator,
              }.merge(notice_trigger.notice_trigger_element_group.notice_peferences)).deliver
  end
end
