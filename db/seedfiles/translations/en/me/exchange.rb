# frozen_string_literal: true

EXCHANGE_TRANSLATIONS = {
  "en.exchange.employer_applications.applications" => "applications",
  "en.exchange.employer_applications.start_date" => "Start Date",
  "en.exchange.employer_applications.end_date" => "End Date",
  "en.exchange.employer_applications.oe_start" => "Open Enrollment Start",
  "en.exchange.employer_applications.oe_end" => "Open Enrollment End",
  "en.exchange.employer_applications.created_on" => "Created On",
  "en.exchange.employer_applications.terminated_on" => "Terminated On",
  "en.exchange.employer_applications.status" => "Status",
  "en.exchange.employer_applications.terminate" => "Terminate",
  "en.exchange.employer_applications.cancel" => "Cancel",
  "en.exchange.employer_applications.continue" => "Continue",
  "en.exchange.employer_applications.confirmation_message" => "Would you like to reinstate the plan year?",
  "en.exchange.employer_applications.success_message" => "Plan Year Reinstated Successfully Effective",
  "en.exchange.employer_applications.unable_to_reinstate" => "An error occured when reinstating application.",
  "en.exchange.employer_applications.reinstate" => "Reinstate",
  "en.exchange.employer_applications.reinstate.modal_warning" => "Unable to Reinstate",
  "en.exchange.employer_applications.reinstate.coverage_exists" => "Active Coverage/Enrollment exists with Effective date ",
  "en.exchange.employer_applications.reinstate.employee_not_active" => "This employee is no longer 'active' on the employers roster. If you proceed, the census record will also be reinstated to an 'active' state.",
  "en.exchange.employer_applications.reinstate.cobra_not_active" => "This COBRA employee is no longer 'active' on the employers roster. If you proceed, the COBRA census record will also be reinstated to an 'active' state.",
  "en.exchange.employer_applications.reinstate.not_eligible_term_reason" => "Termination Reason Not Eligible for Reinstate",
  "en.exchange.employer_applications.reinstate.ivl_term" => "Unable to reinstate Individual Market enrollment for effective date %{date}. Previous year terminated enrollment can't be reinstated, Please reinstate for current year terminated enrollment.",
  "en.exchange.employer_applications.reinstate.employee_cobra" => "Unable to reinstate employer sponsored enrollment for cobra employee.",
  "en.exchange.employer_applications.reinstate.cobra_employee" => "Unable to reinstate cobra enrollment for active employee.",
  "en.exchange.employer_applications.reinstate.esi_coverage_date" => "Unable to reinstate Employer Sponsored enrollment, Employer not offering coverage for the effective date ",
  "en.exchange.employer_applications.voluntary_term" => "Voluntary Termination",
  "en.exchange.employer_applications.non_payment_term" => "Non-Pay Termination",
  "en.exchange.employer_applications.transmit_to_carrier" => "Transmit to Carrier",
  "en.exchange.employer_applications.submit" => "Submit",
  "en.exchange.employer_applications.no_valid_pys" => "No valid plan years present for",
  "en.exchange.employer_applications.select_term_reason" => "Please select terminate reason",
  "en.exchange.manage_sep_types.create_sep_type" => "Create SEP Type",
  "en.exchange.manage_sep_types.description" => "Fill out the information below to create a SEP.",
  "en.exchange.manage_sep_types.create_draft" => "Create Draft",
  "en.exchange.manage_sep_types.cancel" => "Cancel",
  "en.exchange.manage_sep_types.update_sep_type" => "Update SEP Type",
  "en.exchange.manage_sep_types.sep_type_details" => "SEP Type Details",
  "en.exchange.manage_sep_types.update_sep_types" => "Update SEP Type",
  "en.exchange.manage_sep_types.expire_sep_types" => "Expire Sep Type",
  "en.exchange.manage_sep_types.expire" => "Expire",
  "en.exchange.manage_sep_types.title" => "Title",
  "en.exchange.manage_sep_types.self_attestation" => "Self Attestation",
  "en.exchange.manage_sep_types.market_kind" => "Market Kind",
  "en.exchange.manage_sep_types.visibility" => "Visibility",
  "en.exchange.manage_sep_types.sep_eligibility_kinds" => "SEP Eligibility Kind",
  "en.exchange.manage_sep_types.date_options" => "Date Options Available",
  "en.exchange.manage_sep_types.start_date" => "Start date",
  "en.exchange.manage_sep_types.end_date" => "End date",
  "en.exchange.manage_sep_types.sep_name" => "SEP Name",
  "en.exchange.manage_sep_types.tooltip" => "SEP Name Tool Tip",
  "en.exchange.manage_sep_types.tooltip_content" => "Enter SEP Name Tool Tip",
  "en.exchange.manage_sep_types.event_date_label" => "Event Date Label",
  "en.exchange.manage_sep_types.event_date_label_placeholder" => "Enter Event Date Label",
  "en.exchange.manage_sep_types.reason" => "SEP Reason",
  "en.exchange.manage_sep_types.reason.choose" => "Choose",
  "en.exchange.manage_sep_types.eligible_before" => "Days Eligible Before Event Date",
  "en.exchange.manage_sep_types.eligible_after" => "Days Eligible After Event Date",
  "en.exchange.manage_sep_types.effective_date_rules" => "Effective Date Rules",
  "en.exchange.manage_sep_types.market_kind.individual" => "Individual",
  "en.exchange.manage_sep_types.is_self_attested.true" => "Self-Service",
  "en.exchange.manage_sep_types.is_self_attested.false" => "Admin Only",
  "en.exchange.manage_sep_types.reason.adoption" => "Adoption",
  "en.exchange.manage_sep_types.reason.birth" => "Birth",
  "en.exchange.manage_sep_types.reason.child_age_off" => "Child Age Off",
  "en.exchange.manage_sep_types.reason.contract_violation" => "Contract Violation",
  "en.exchange.manage_sep_types.reason.court_order" => "Court Order",
  "en.exchange.manage_sep_types.reason.death" => "Death",
  "en.exchange.manage_sep_types.reason.divorce" => "Divorce",
  "en.exchange.manage_sep_types.reason.domestic_partnership" => "Domestic Partnership",
  "en.exchange.manage_sep_types.reason.eligibility_change_employer_ineligible" => "Employer Ineligible",
  "en.exchange.manage_sep_types.reason.eligibility_change_immigration_status" => "Citizenship Immigration Change",
  "en.exchange.manage_sep_types.reason.eligibility_change_income" => "Income Change",
  "en.exchange.manage_sep_types.reason.eligibility_change_medicaid_ineligible" => "Medicaid Ineligible",
  "en.exchange.manage_sep_types.reason.eligibility_documents_provided" => "Eligibility Documents",
  "en.exchange.manage_sep_types.reason.eligibility_failed_or_documents_not_received_by_due_date" => "Marketplace Ineligible",
  "en.exchange.manage_sep_types.reason.employee_gaining_medicare" => "Employee Gaining Medicare",
  "en.exchange.manage_sep_types.reason.employer_sponsored_coverage_termination" => "Employer Unpaid Premium",
  "en.exchange.manage_sep_types.reason.enrollment_error_or_misconduct_hbx" => "Enrollment Error HBX",
  "en.exchange.manage_sep_types.reason.enrollment_error_or_misconduct_issuer" => "Enrollment Error Carrier",
  "en.exchange.manage_sep_types.reason.enrollment_error_or_misconduct_non_hbx" => "Enrollment Error Assister Broker",
  "en.exchange.manage_sep_types.reason.exceptional_circumstances" => "Exceptional Circumstances",
  "en.exchange.manage_sep_types.reason.exceptional_circumstances_civic_service" => "Americorps",
  "en.exchange.manage_sep_types.reason.exceptional_circumstances_domestic_abuse" => "Domestic Abuse",
  "en.exchange.manage_sep_types.reason.exceptional_circumstances_medical_emergency" => "Medical Emergency",
  "en.exchange.manage_sep_types.reason.exceptional_circumstances_natural_disaster" => "Natural Disaster",
  "en.exchange.manage_sep_types.reason.exceptional_circumstances_system_outage" => "System Outage",
  "en.exchange.manage_sep_types.reason.lost_access_to_mec" => "Lost Other MEC",
  "en.exchange.manage_sep_types.reason.lost_hardship_exemption" => "Lost Hardship Exemption",
  "en.exchange.manage_sep_types.reason.marriage" => "Marriage",
  "en.exchange.manage_sep_types.reason.new_eligibility_family" => "Drop New Eligibility",
  "en.exchange.manage_sep_types.reason.new_eligibility_member" => "Drop Family New Eligibility",
  "en.exchange.manage_sep_types.reason.new_employment" => "New Employment",
  "en.exchange.manage_sep_types.reason.qualified_native_american" => "Native American",
  "en.exchange.manage_sep_types.reason.relocate" => "Moved",
  "en.exchange.manage_sep_types.effective_on_kinds.date_of_event" => "Date of Event",
  "en.exchange.manage_sep_types.effective_on_kinds.date_of_event_plus_one" => "Date of event + 1",
  "en.exchange.manage_sep_types.effective_on_kinds.first_of_this_month" => "First of Event Month",
  "en.exchange.manage_sep_types.effective_on_kinds.fixed_first_of_next_month" => "First of Month after Event",
  "en.exchange.manage_sep_types.effective_on_kinds.first_of_reporting_month" => "First of Reporting Month",
  "en.exchange.manage_sep_types.effective_on_kinds.first_of_next_month_reporting" => "First of Month after Reporting",
  "en.exchange.manage_sep_types.effective_on_kinds.first_of_month" => "15th of the Month",
  "en.exchange.manage_sep_types.effective_on_kinds.first_of_next_month_coinciding" => "First of Next Month (Coinciding)",
  "en.exchange.manage_sep_types.effective_on_kinds.first_of_next_month_plan_selection" => "First of Next Month (Plan Selection)",
  "en.exchange.manage_sep_types.effective_on_kinds.first_of_the_month_plan_shopping" => "First of the Month (Plan Shopping)",
  "en.exchange.manage_sep_types.effective_on_kinds.first_of_the_month_coinciding" => "First of the Month (Coinciding)",
  "en.exchange.manage_sep_types.is_visible.true" => "Customer & Admin",
  "en.exchange.manage_sep_types.is_visible.false" => "Admin Only",
  "en.exchange.manage_sep_types.date_options_available.true" => "True",
  "en.exchange.manage_sep_types.date_options_available.false" => "False",
  "en.exchange.manage_sep_types.qle_event_date_kind.qle_on" => "Event Date",
  "en.exchange.manage_sep_types.qle_event_date_kind.submitted_at" => "Reported Date",
  "en.exchange.manage_sep_types.terminate_on" => "Termination On",
  "en.exchange.manage_sep_types.coverage_start_on" => "Eligibility Start Date",
  "en.exchange.manage_sep_types.coverage_end_on" => "Eligibility End Date",
  "en.exchange.manage_sep_types.publish_sep_types" => "Publish SEP Type",
  "en.exchange.manage_sep_types.publish" => "Publish",
  "en.exchange.manage_sep_types.state" => "State",
  "en.exchange.manage_sep_types.manage_seps" => "Manage SEPs",
  "en.exchange.manage_sep_types.sorting_sep_types" => "Sort SEPs",
  "en.exchange.manage_sep_types.create_sep_types" => "Create SEP",
  "en.exchange.manage_sep_types.sort_sep_types" => "Sort SEP Types",
  "en.exchange.manage_sep_types.individual" => "Individual",
  "en.exchange.manage_sep_types.shop" => "Shop",
  "en.exchange.manage_sep_types.fehb" => "Congress",
  "en.exchange.manage_sep_types.sep_type_list" => "List SEP Types",
  "en.exchange.manage_sep_types.titles" => "SEPs",
  "en.exchange.manage_sep_types.sort_description" => "Drag and drop to change the order that the SEPs appear to customer or admin. This list includes all SEPs. SEPs with Admin Only visibility will show on this list and on the Admin SEP menu and carousel, but will not show on the customer SEP carousel.",
  "en.exchange.manage_sep_types.threshold" => "Most Common Life Changes",
  "en.exchange.manage_sep_types.threshold_amount" => "Amount",
  "en.exchange.manage_sep_types.rare_header" => "Less Common Life Changes",
  "en.exchange.manage_sep_types.update_success" => "SEP Type list successfully sorted",
  "en.exchange.manage_sep_types.update_error" => "SEP Type list failed to sort",
  "en.exchange.manage_sep_types.enter_sep_name" => "Enter SEP name",
  "en.exchange.security_questions.error_cant_save" => "prohibited this question from being saved:",
  "en.exchange.securty_questions.edit_question" => "Edit Question",
  "en.exchange.securty_questions.back" => "Back",
  "en.exchange.employer_applications.title" => "Title",
  "en.exchange.employer_applications.created" => "Created",
  "en.exchange.employer_applications.actions" => "Actions",
  "en.exchange.employer_applications.new_question" => "New Question",
  "en.exchange.employer_applications.security_questions" => "Security Questions",
  "en.exchange.broker_applicants.details" => "Applicant Details",
  "en.exchange.broker_applicants.broker_hbx" => "Broker HBX ID",
  "en.exchange.broker_applicants.carrier_apts" => "Carrier Appointments",
  "en.documents.controller.missing_document_message" => "Unable to find document with specified ID. Please contact customer service at %{contact_center_phone_number}.",
  "en.documents.need_employee_template" => "Need the new template? Download it now.",
  "en.exchange.seeds.page_title" => "Data Seeds",
  "en.exchange.error" => "Error",
  'en.exchanges.security_questions.denied_access_message' => 'Security Questions feature is not enabled. You are not allowed to create, edit, view or delete security questions.'
}.freeze
