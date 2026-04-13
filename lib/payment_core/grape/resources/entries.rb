module PaymentCore
  module Grape
    module Resources
      class Entries < ::PaymentCore::Grape::Resources::Base

        include ::PaymentCore::Grape::Helpers::Entries

        inheritable_class_attribute :entry_name
        self.entry_name = "entry"

        fetch_resource_and_collection! do
          model_klass do
            entry_class
          end
        end

        class << self
          def draw(*args, &block)
            opts = args.extract_options!
            resource_name = args[0] || "entry"
            return unless resource_name

            klass = duplicate(self)
            klass.entry_name = resource_name
            klass.class_exec(&block) if block_given?
            opts = { index: true, create: false, resources_actions: false, show: true, update: false, destroy: false, resource_actions: false }.merge(opts)
            subject = resource_name.to_s.singularize.to_sym

            resources_path = resource_name.to_s.pluralize
            klass.resources resources_path do
              get "", authorize: [:read, subject], model_name: proc { model_klass }, action_name: "index" do
                presenter records, locals: presenter_local_options
              end if opts[:index]
            end

            resource_path = resource_name.to_s.singularize
            klass.resource "#{resource_path}/:id" do
              get "", authorize: [:read, subject], model_name: proc { model_klass }, action_name: "show" do
                presenter record, locals: presenter_local_options
              end if opts[:show]
            end

            klass
          end
        end
      end
    end
  end
end
