module PaymentCore
  module Grape
    module Helpers
      module Entries
        def self.included(base)
          base.helpers HelperMethods
        end

        module HelperMethods
          def entry_class
            return @entry_class if @entry_class

            @entry_class = entry_class_finder
            raise ::ActiveRecord::RecordNotFound unless @entry_class

            @entry_class
          end

          def entry_class_finder(identifier = class_context.entry_name)
            ::PaymentCore::Models::Decorators::Entry::Object.registered_classes.find do |klass|
              klass.entry_name.to_s.pluralize == identifier.to_s.pluralize
            end
          end
        end
      end
    end
  end
end
