module Effective
  module Datatables
    class BrokerAgencyDatatable < Effective::MongoidDatatable
      DATA_STORE = Effective::Datatables::DataStores::BrokerFamilyCountDataStore # data store for broker family count

      datatable do
        # bulk_actions_column do
        #    bulk_action 'Generate Invoice', generate_invoice_exchanges_hbx_profiles_path, data: { confirm: 'Generate Invoices?', no_turbolink: true }
        #    bulk_action 'Mark Binder Paid', binder_paid_exchanges_hbx_profiles_path, data: {  confirm: 'Mark Binder Paid?', no_turbolink: true }
        # end

        table_column :legal_name, :label => l10n('legal_name'), :proc => proc { |row|
          #row.legal_name
          #(link_to row.legal_name.titleize, employers_employer_profile_path(@employer_profile, :tab=>'home')) + raw("<br>") + truncate(row.id.to_s, length: 8, omission: '' )
          #link_to broker_agency_profile.legal_name, broker_agencies_profile_path(broker_agency_profile)
                                                                           link_to h(row.legal_name), benefit_sponsors.profiles_broker_agencies_broker_agency_profile_path(row.broker_agency_profile)
                                                                         }, :sortable => true, :filter => false, :width => '30%'

        table_column :dba, :label => l10n('dba_caps'), :proc => proc { |row|
          h(row.dba)
        }, :sortable => false, :filter => false, :width => '20%'
        table_column(:active_families_count, :label => l10n('families_count'), :proc => proc { |row| DATA_STORE.fetch_field(row) }, :sortable => true, :filter => false, :width => '20%') if EnrollRegistry.feature_enabled?(:broker_family_count)
        table_column :fein, :label => l10n('fein'), :proc => proc { |row| row.fein }, :sortable => false, :filter => false, :width => '10%'

        table_column :entity_kind, :label => l10n('entity_kind'), :proc => proc { |row| row.entity_kind.to_s.titleize }, :sortable => false, :filter => false, :width => '10%'
        table_column :market_kind, :label => l10n('market'), :proc => proc { |row| row.broker_agency_profile.market_kind.to_s.titleize }, :sortable => false, :filter => false, :width => '10%'

        default_order :legal_name, :asc
      end

      def collection
        @collection ||= Queries::BrokerAgencyDatatableQuery.new(attributes, data_store: DATA_STORE)
      end

      def global_search?
        true
      end

      def nested_filter_definition
        return nil if EnrollRegistry.feature_enabled?(:bs4_admin_flow)
        {
          broker_agencies:
            [
              {scope: 'all', label: 'All'}
            ],
          top_scope: :broker_agencies
        }
      end

      def authorized?(current_user, _controller, _action, _resource)
        current_user.has_hbx_staff_role?
      end
    end
  end
end
