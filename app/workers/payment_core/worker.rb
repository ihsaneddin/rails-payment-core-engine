module PaymentCore
  class Worker
    include Sidekiq::Worker

    attr_accessor :id
    class_attribute :model

    def perform(id, action, *args)
      self.id = id
      callback(:before)
      send(action, *args)
      callback(:after)
    end

    protected

      def resource &block
        if model
          @resource ||= model.find_by_id(self.id)
          if block_given? && @resource
            yield(@resource)
          end
        end
      end

      def model
        self.class.model
      end

      def callback(key, *args, config: ::PaymentCore.config.sidekiq.callbacks)
        if config.exists?(key)
          config.with_context(self) do
            config.send(key, *args)
          end
        end
      end
  end
end
