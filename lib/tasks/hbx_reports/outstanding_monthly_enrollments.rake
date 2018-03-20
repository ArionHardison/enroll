require 'csv'

# The idea behind this report is to get a list of all of the enrollments for an employer and what is currently in Glue. 
# Steps
# 1) You need to pull a list of enrollments from glue (bundle exec rails r script/queries/print_all_policy_ids > all_glue_policies.txt -e production)
# 2) Place that file into the Enroll Root directory. 
# 3) Run the below rake task
# RAILS_ENV=production bundle exec rake reports:outstanding_monthly_enrollments start_date='04/01/2018'

namespace :reports do 

  desc "Outstanding Enrollments by Employer"
  task :outstanding_monthly_enrollments => :environment do
    effective_on = ENV['start_date'].to_date

    Dir.mkdir("hbx_report") unless File.exists?("hbx_report")

    glue_list = File.read("all_glue_policies.txt").split("\n").map(&:strip)

    field_names = ['Employer ID', 'Employer FEIN', 'Employer Name', 'Employer Plan Year Start Date', 'Plan Year State', 'Enrollment Group ID', 
                   'Enrollment Purchase Date/Time', 'Coverage Start Date', 'Enrollment State', 'Subscriber HBX ID', 'Subscriber First Name','Subscriber Last Name','Policy in Glue?']
    CSV.open("#{Rails.root}/hbx_report/#{ENV['start_date']}_employer_enrollments_#{Time.now.strftime('%Y%m%d%H%M')}.csv","w") do |csv|
      csv << field_names
      feins = Organization.where(:"employer_profile.plan_years" => { :$elemMatch => {:start_on => effective_on} }).map(&:fein)
      enrollment_ids = Queries::NamedPolicyQueries.shop_monthly_enrollments(feins, effective_on)
      enrollment_ids.each do |id|
        hbx_enrollment = HbxEnrollment.by_hbx_id(id).first
        employer_profile = hbx_enrollment.employer_profile
        employer_id = employer_profile.hbx_id
        fein = employer_profile.fein
        legal_name = employer_profile.legal_name
        plan_year = hbx_enrollment.benefit_group.plan_year
        plan_year_start = plan_year.start_on.to_s
        plan_year_state = plan_year.aasm_state
        eg_id = id
        purchase_time = hbx_enrollment.created_at
        coverage_start = hbx_enrollment.effective_on
        enrollment_state = hbx_enrollment.aasm_state 
        subscriber = hbx_enrollment.subscriber
        if subscriber.present? && subscriber.person.present?
          subscriber_hbx_id = subscriber.hbx_id
          first_name = subscriber.person.first_name
          last_name = subscriber.person.last_name
        end
        in_glue = glue_list.include?(id)
        csv << [employer_id,fein,legal_name,plan_year_start,plan_year_state,eg_id,purchase_time,coverage_start,enrollment_state,subscriber_hbx_id,first_name,last_name,in_glue]
      end
    end
  end
end