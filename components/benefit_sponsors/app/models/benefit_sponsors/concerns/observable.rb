module BenefitSponsors
  module Concerns::Observable
    extend ActiveSupport::Concern

    included do
      def notify_observers(args={})
        if self.class.observer_peers.any?
          self.class.observer_peers.each do |k, events|
            events.each do |event|
              if args.present? && k.is_a?(args.options[:observer_klass] || BenefitSponsors::Observers::NoticeObserver)
                k.send event, self, args
              end
            end
          end
        end
      end
    end

    class_methods do
      def add_observer(observer, func=:update)
        @observer_peers ||= {}
        func = Array.wrap(func)
        unless func.all? {|event| observer.respond_to? event}
          raise NoMethodError, "observer does not respond to '#{func.to_s}'"
        end

        if @observer_peers.none?{|k, v| k.is_a?(observer.class)}
          @observer_peers[observer] = func
        end
        @observer_peers
      end

      def observer_peers
        @observer_peers || ancestors[1..-1].map { |a| a.observer_peers if a.respond_to?(:observer_peers) }.compact.first
      end
    end
  end
end
