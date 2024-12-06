# frozen_string_literal: true

module Subscribers
  # Subscriber responsible for receiving reingested ATP payloads from Medicaid Gateway, processing them.
  # It listens to the `magi_medicaid.atp_reingest.enroll` queue and handles the `on_transfer_in` event.
  class AtpReingestSubscriber
    include EventSource::Logging
    include ::EventSource::Subscriber[amqp: 'magi_medicaid.atp_reingest.enroll']

    subscribe(:on_transfer_in) do |delivery_info, _metadata, response|
      logger.info "AtpReingestSubscriber: invoked on_magi_medicaid_atp_reingest_enroll with delivery_info: #{delivery_info}, response: #{response}"

      payload = JSON.parse(response, symbolize_names: true)
      result = FinancialAssistance::Operations::Transfers::MedicaidGateway::AccountTransferReingest.new.call(payload)

      if result.success?
        FinancialAssistance::Operations::Transfers::MedicaidGateway::AccountTransferResponse.new.call(result.value!)
        ack(delivery_info.delivery_tag)
        logger.info "AtpReingestSubscriber: acked with success: #{result.success}"
      else
        nack(delivery_info.delivery_tag)
        logger.info "AtpReingestSubscriber: nacked with failure, errors: #{result.failure}"
      end
    rescue StandardError => e
      nack(delivery_info.delivery_tag)
      logger.error "AtpReingestSubscriber: error_message: #{e.message}, backtrace: #{e.backtrace}"
    end
  end
end
