module BenefitSponsors
  module Services
    class BenefitApplicationService
      attr_reader :benefit_application_factory, :benefit_sponsorship

      def initialize(factory_kind = BenefitSponsors::BenefitApplications::BenefitApplicationFactory)
        @benefit_application_factory = factory_kind
      end

      # load defaults from models
      def load_default_form_params(form)
        form
      end

      def load_form_metadata(form)
        schedular = BenefitSponsors::BenefitApplications::BenefitApplicationSchedular.new
        form.start_on_options = schedular.start_on_options_with_schedule
      end

      def load_form_params_from_resource(form)
        benefit_application = find_model_by_id(form.id)
        attributes_to_form_params(benefit_application, form)
      end
  
      def save(form)
        model_attributes = form_params_to_attributes(form)
        benefit_sponsorship = find_benefit_sponsorship(form)
        benefit_application = benefit_application_factory.call(benefit_sponsorship, model_attributes) # build cca/dc application
        store(form, benefit_application)
      end

      def revert(form)
        benefit_application = find_model_by_id(form.id)
        if benefit_application.may_revert_renewal?
          if benefit_application.revert_renewal!
            return [true, benefit_application]
          else
            get_application_errors_for_revert(benefit_application, form)
          end
        elsif benefit_application.may_revert_application?
          if benefit_application.revert_application!
            return [true, benefit_application]
          else
            get_application_errors_for_revert(benefit_application, form)
          end
        end
        form.errors.add(:base, "Benefit Application is not eligible to revert")
        [false, benefit_application]
      end

      def force_publish(form)
        benefit_application = find_model_by_id(form.id)
        benefit_application.force_publish!
        [true, benefit_application]
      end

      def publish(form)
        benefit_application = find_model_by_id(form.id)
        serivce = BenefitApplicationEnrollmentService.new(benefit_application)
        saved, benefit_application, errors = service.submit_application

        unless save
          errors.each do |k, v|
            form.errors.add(k, v)
          end
        end
      end
     
      def update(form) 
        benefit_application = find_model_by_id(form.id)
        model_attributes = form_params_to_attributes(form)
        benefit_application.assign_attributes(model_attributes)
        store(form, benefit_application)
      end
    
      # TODO: Test this query for benefit applications cca/dc
      # TODO: Change it back to find once find method on BenefitApplication is fixed.
      def find_model_by_id(id)
        BenefitSponsors::BenefitApplications::BenefitApplication.where(id: id).first
      end

      # TODO: Change it back to find once find method on BenefitSponsorship is fixed.
      def find_benefit_sponsorship(form)
        return @benefit_sponsorship if defined? @benefit_sponsorship
        @benefit_sponsorship = BenefitSponsors::BenefitSponsorships::BenefitSponsorship.where(id: form.benefit_sponsorship_id).first
      end

      def attributes_to_form_params(benefit_application,form)
        form.attributes = {
          start_on: format_date_to_string(benefit_application.effective_period.min),
          end_on: format_date_to_string(benefit_application.effective_period.max),
          open_enrollment_start_on: format_date_to_string(benefit_application.open_enrollment_period.min),
          open_enrollment_end_on: format_date_to_string(benefit_application.open_enrollment_period.max),
          fte_count: benefit_application.fte_count,
          pte_count: benefit_application.pte_count,
          msp_count: benefit_application.msp_count
        }
      end

      def form_params_to_attributes(form)
        {
          effective_period: (format_string_to_date(form.start_on)..format_string_to_date(form.end_on)),
          open_enrollment_period: (format_string_to_date(form.open_enrollment_start_on)..format_string_to_date(form.open_enrollment_end_on)),
          fte_count: form.fte_count,
          pte_count: form.pte_count,
          msp_count: form.msp_count
        }
      end

      #TODO: FIX date format
      def format_string_to_date(date)
        if date.split('/').first.size == 2
          Date.strptime(date,"%m/%d/%Y")
        elsif date.split('-').first.size == 4
          Date.strptime(date,"%Y-%m-%d")
        end
      end

      def format_date_to_string(date)
        date.to_date.to_s
      end

      def store(form, benefit_application)
        valid_according_to_factory = benefit_application_factory.validate(benefit_application)
        if valid_according_to_factory
          benefit_sponsorship = benefit_application.benefit_sponsorship || find_benefit_sponsorship(form)
          benefit_application.benefit_sponsor_catalog = benefit_sponsorship.benefit_sponsor_catalog_for(benefit_application.effective_period.begin)
        else
          map_errors_for(benefit_application, onto: form)
          return [false, nil]
        end
        save_successful = benefit_application.save
        unless save_successful 
          map_errors_for(benefit_application, onto: form)
          return [false, nil]
        end
        [true, benefit_application]
      end

      def map_errors_for(benefit_application, onto:)
        benefit_application.errors.each do |att, err|
          onto.errors.add(map_model_error_attribute(att), err)
        end
      end

      # We can cheat here because our form and our model are so
      # close together - normally this will be more complex
      def map_model_error_attribute(model_attribute_name)
        model_attribute_name
      end

      private

      def get_application_errors_for_revert(benefit_application, form)
        errors = benefit_application.errors.full_messages.merge(benefit_application.application_errors)
        errors.each do |k, v|
          form.errors.add(k, v)
        end
        return [false, benefit_application]
      end
      
    end
  end
end