module ConsumerRolesHelper
  def ethnicity_collection
    [
      ["White", "Black or African American", "Asian Indian", "Chinese" ],
      ["Filipino", "Japanese", "Korean", "Vietnamese", "Other Asian"],
      ["Native Hawaiian", "Samoan", "Guamanian or Chamorro", ],
      ["Other Pacific Islander", "American Indian/Alaska Native", "Other"]

    ].inject([]){ |sets, ethnicities|
      sets << ethnicities.map{|e| OpenStruct.new({name: e, value: e})}
    }
  end

  def latino_collection
    [
      ["Mexican", "Mexican American"],
      ["Chicano/a", "Puerto Rican"],
      ["Cuban", "Other"]
    ].inject([]){ |sets, ethnicities|
      sets << ethnicities.map{|e| OpenStruct.new({name: e, value: e})}
    }
  end

  def find_consumer_role_for_fields(obj)
    if obj.is_a? Person
      obj.consumer_role
    elsif obj.persisted? && obj.family_member.present?
      obj.family_member.person.consumer_role
    else
      ConsumerRole.new
    end
  end

  def show_naturalized_citizen_container(obj)
    obj.try(:us_citizen)
  end

  def show_immigration_status_container(obj)
    obj.try(:us_citizen) == false
  end

  def show_tribal_container(obj)
    obj.try(:indian_tribe_member)
  end

  def featured_tribes_collection
    FinancialAssistanceRegistry[:featured_tribes_selection].setting(:featured_tribes).item.map{|a| OpenStruct.new({name: a.first, value: a.last})}
  end

  def show_naturalization_doc_type(obj)
    show_naturalized_citizen_container(obj) and obj.try(:naturalized_citizen)
  end

  def show_immigration_doc_type(obj)
    show_immigration_status_container(obj) and obj.try(:eligible_immigration_status)
  end

  def show_vlp_documents_container(obj)
    show_naturalization_doc_type(obj) || show_immigration_doc_type(obj)
  end

  # just work for ivl
  def show_keep_existing_plan(shop_for_plans, hbx_enrollment, new_effective_on)
    return true if hbx_enrollment.is_shop?

    shop_for_plans.blank? && (hbx_enrollment.effective_on.year == (new_effective_on.present? ? new_effective_on.year : nil))
  end

  def is_applying_coverage_value_consumer(use_person, person, consumer_role)
    first_checked = true
    second_checked = false
    if use_person.present?
      first_checked = person.is_applying_coverage == 'true'
      second_checked = person.is_applying_coverage == 'false'
    elsif consumer_role.present?
      first_checked = consumer_role.is_applying_coverage
      second_checked = !consumer_role.is_applying_coverage
    end
    return first_checked, second_checked
  end

  # Allow flow to the next page if app or ID verified, otherwise stay on the same page
  def ridp_redirection_link(person)
    consumer_redirection_path = EnrollRegistry.feature_enabled?(:financial_assistance) ? help_paying_coverage_insured_consumer_role_index_path : insured_family_members_path(consumer_role_id: person.consumer_role.id)
    consumer = person.consumer_role
    app_type = person.primary_family.application_type
    admin_user =  current_user.has_hbx_staff_role?
    id_verified = consumer.identity_verified?
    app_verified = consumer.application_verified?
    return consumer_redirection_path if app_verified || id_verified
    consumer.admin_bookmark_url.present? ? consumer.admin_bookmark_url : request.env['PATH_INFO']
  end
end
