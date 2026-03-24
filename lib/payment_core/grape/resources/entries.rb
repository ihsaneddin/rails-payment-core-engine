module PaymentCore
  module Grape
    module Resources
      class Entries < ::PaymentCore::Grape::Resources::Base
        fetch_resource_and_collection! do
          model_klass "PaymentCore::Entry"

          query_scope do |query|
            query.where.not(id: nil)
          end
        end

        class << self
          def draw(*args, &block)
            opts = args.extract_options!
            resource_name = args[0]
            return unless resource_name

            klass = duplicate(self)
            klass.class_exec(&block) if block_given?
            opts = { index: true, create: false, resources_actions: false, show: true, update: false, destroy: false, resource_actions: false }.merge(opts)
            subject = resource_name.to_s.to_sym

            klass.resources resource_name.to_s do
              get "", authorize: [:read, subject], model_name: proc { model_klass }, action_name: "index" do
                presenter records, locals: presenter_local_options
              end if opts[:index]
            end

            singular = resource_name.to_s.singularize
            klass.resource "#{singular}/:id" do
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
