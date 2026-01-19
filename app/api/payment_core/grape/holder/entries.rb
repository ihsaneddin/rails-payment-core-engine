module PaymentCore
  module Grape
    module Holder
      class Entries < Base

        inheritable_class_attribute :entry_class_finder, :entry_name
        self.entry_name = "entry"
        self.entry_class_finder = proc { |entry_name|
          ::PaymentCore::Models::Decorators::Entry::Object.registered_classes.select{|entry_class| entry_class.entry_name.to_s == entry_name.singularize.to_s }[0]
        }

        fetch_resource_and_collection! do
          model_klass do
            entry_class
          end
        end

        helpers do

          def entry_class
            unless @entry_class
              @entry_class = instance_exec(class_context.entry_name, &class_context.entry_class_finder)
              raise ::ActiveRecord::RecordNotFound unless @entry_class
            end
            @entry_class
          end

        end

        class << self

          def draw *args, &block
            opts = args.extract_options!
            entry_name = args[0]
            return unless entry_name
            klass = duplicate(self)
            klass.entry_name = entry_name.to_s.singularize
            klass.class_exec(&block) if block_given?
            opts = {index: true, create: true, resources_actions: true, show: true, update: true, destroy: true, resource_actions: true}.merge(opts)
            subject = entry_name.to_s.to_sym
            klass.resources "#{entry_name}" do
              if opts[:index]
                get "", authorize: [:read, subject ], model_name: proc { model_klass }, action_name: "index" do
                  presenter records, locals: presenter_local_options
                end
              end

              if opts[:create]
                post "", authorize: [:create, subject ], model_name: proc { model_klass }, action_name: "create" do
                  if record.save
                    presenter record, locals: presenter_local_options
                  else
                    standard_validation_error(details: record.errors)
                  end
                end
              end
              if opts[:resources_actions]
                namespace :action do
                  collection_actions_for(base.model_klass, base.resource_context, authorize: [:action, subject ], model_name: proc { model_klass }, action_name: "#{subject}_action")
                end
              end
            end
            klass.resource "#{entry_name}/:id" do

              if opts[:show]
                get "", authorize: [:read, subject ], model_name: proc { model_klass }, action_name: "show" do
                  presenter record, locals: presenter_local_options
                end
              end

              if opts[:update]
                put "", authorize: [:update, subject ], model_name: proc { model_klass }, action_name: "update" do
                  if record.update(permitted_attributes)
                    presenter record, locals: presenter_local_options
                  else
                    standard_validation_error(details: record.errors)
                  end
                end
              end

              if opts[:destroy]
                delete "", authorize: [:destroy, subject ], model_name: proc { model_klass }, action_name: "destroy" do
                  if record.destroy
                    presenter record, locals: presenter_local_options
                  else
                    standard_validation_error(details: record.errors)
                  end
                end
              end

              if opts[:resource_actions]
                namespace :action do
                  resource_actions_for(base.model_klass, base.resource_context, authorize: [:action, subject ], model_name: proc { model_klass }, action_name: "#{subject}_action")
                end
              end

            end
            klass
          end

          def draws *args, &block
            opts = args.extract_options!
            entry_names = args
            entry_names.map do |entry_name|
              klass = draw(entry_name, opts, &block)
              klass
            end
          end

        end

      end
    end
  end
end
