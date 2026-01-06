module PaymentCore
  module Configuration
    class Models < Plugins::Models::FieldOptions

      #embeds_many :orders, class_name: "PaymentCore::Configuration:::Models::Model"

      def set_as_default(key, model)
        send(key).each do |m|
          if m.name == model.name
            m.set_default
          else
            m.set_non_default
          end
        end
      end

      def enable key, *names
        send(key).select{|m| names.map(&:to_s).include?(m.name.to_s) }.each(&:enable)
      end

      def disable key, *names
        send(key).select{|m| names.map(&:to_s).include?(m.name.to_s) }.each(&:disable)
      end

      def delete_mod key, class_name
        res = send(key)#.select{|m| names.map(&:to_s).include?(m.name.to_s) }.each(&:disable)
        res = res.reject{|mod| mod.class_name == class_name  }
        send("#{key}=", [])
        res.each{|mod| send(key).append(mod)}
      end

      class Model <  Plugins::Models::FieldOptions

        attribute :name
        attribute :class_name
        attribute :default, :boolean, default: false
        attribute :enabled, :boolean, default: false

        def name
          super.to_s
        end

        def set_default
          self.default= true
        end

        def set_non_default
          self.default= false
        end

        def enable
          self.enabled= true
        end

        def disable
          self.enabled= false
        end

      end

      def model
        PaymentCore::Configuration::Models::Model
      end

    end
  end
end