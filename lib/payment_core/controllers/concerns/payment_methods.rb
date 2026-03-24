require "json"

module PaymentCore
  module Controllers
    module Concerns
      module PaymentMethods
        extend ActiveSupport::Concern

        included do
          helper_method :payment_method_types_for_select,
                        :selected_payment_method_model,
                        :payment_method_type_value,
                        :metadata_fields_for_form,
                        :availability_rule_fields_for_form,
                        :given_context,
                        :member_processor_actions_for,
                        :collective_processor_actions_for,
                        :processor_param_fields_for,
                        :payable_type_options_for_select,
                        :payable_grouped_options_for_select,
                        :payment_method_options_for_select,
                        :processor_field_input_name,
                        :collection_processor_for,
                        :current_processor_payer
        end

        def payment_method_types_for_select
          registered_payment_method_classes.map do |klass|
            ["#{klass.method_type.to_s.humanize} (#{klass.name.demodulize})", klass.name]
          end
        end

        def payment_method_type_value
          params[:type].presence ||
            params.dig(:payment_method, :type).presence ||
            record&.type.presence ||
            selected_payment_method_model.name
        end

        def selected_payment_method_model
          @selected_payment_method_model ||= begin
            raw_type = payment_method_type_value.to_s
            raw_type.safe_constantize ||
              registered_payment_method_classes.find do |klass|
                [klass.name, klass.method_type.to_s, klass.method_type.to_s.pluralize].include?(raw_type)
              end ||
              ::PaymentCore::PaymentMethod
          end
        end

        def payment_method_resource_model
          record.is_a?(::PaymentCore::PaymentMethod) ? record.class : selected_payment_method_model
        end

        def payment_method_resource_params_attributes
          payment_method_model = payment_method_resource_model
          metadata_keys = payment_method_model.store_model_klass_of(:metadata).assignable_attributes.map do |key|
            :"metadata_#{key}"
          end
          availability_rule_keys = payment_method_model.store_model_klass_of(:availability_rules).assignable_attributes.map(&:to_sym)

          [
            :type,
            :display_name,
            :label_name,
            :active,
            :always_available,
            :default,
            :holder_type,
            :holder_id,
            :reference_type,
            :reference_id,
            :use_reference,
            :currency,
            :expires_at,
            :external_provider
          ] + metadata_keys + [
            { availability_rules: availability_rule_keys }
          ]
        end

        def normalized_payment_method_attributes(attributes, model = payment_method_resource_model)
          attrs = attributes.to_h.deep_dup.stringify_keys

          metadata_model = model.store_model_klass_of(:metadata).new
          model.store_model_klass_of(:metadata).assignable_attributes.each do |key|
            field_name = "metadata_#{key}"
            next unless attrs.key?(field_name)

            attrs[field_name] = normalize_store_model_value(metadata_model.public_send(key), attrs[field_name])
          end

          if attrs["availability_rules"].respond_to?(:to_h)
            rules = attrs["availability_rules"].to_h.stringify_keys
            rules_model = model.store_model_klass_of(:availability_rules).new
            model.store_model_klass_of(:availability_rules).assignable_attributes.each do |key|
              next unless rules.key?(key.to_s)

              rules[key.to_s] = normalize_store_model_value(rules_model.public_send(key), rules[key.to_s])
            end
            attrs["availability_rules"] = rules
          end

          attrs["type"] = model.name if attrs["type"].blank? && model != ::PaymentCore::PaymentMethod
          attrs
        end

        def metadata_fields_for_form(model = payment_method_resource_model)
          metadata_model = model.store_model_klass_of(:metadata).new
          model.store_model_klass_of(:metadata).assignable_attributes.map do |name|
            value =
              if record.is_a?(::PaymentCore::PaymentMethod)
                record.public_send("metadata_#{name}")
              else
                metadata_model.public_send(name)
              end

            build_form_field(prefix: :metadata, name: name, value: value)
          end
        end

        def availability_rule_fields_for_form(model = payment_method_resource_model)
          rules_model = record.is_a?(::PaymentCore::PaymentMethod) ? record.availability_rules : model.store_model_klass_of(:availability_rules).new
          model.store_model_klass_of(:availability_rules).assignable_attributes.map do |name|
            build_form_field(prefix: :availability_rules, name: name, value: rules_model.public_send(name))
          end
        end

        def given_context
          return @given_context if defined?(@given_context)

          builder = ::PaymentCore.config.payment_method.default_context_builder
          context_opts = params[:context] || {}
          context_opts[:payables] = payables(context_opts[:payables])
          context_opts = { user: current_user, data: params }.merge(context_opts)
          @given_context = builder.is_a?(Proc) ? instance_exec(context_opts, &builder) : builder
        end

        def processor
          return @processor if defined?(@processor)

          @processor =
            if action_name.to_s == "collective_processor_action"
              payment_methods = records.where(method_type: params[:method_type])
              payment_methods = payment_methods.where(id: params[:payment_method_ids]) if params[:payment_method_ids].present?
              ::PaymentCore.config.payment_processor_registry.resolve(params[:method_type]).new(
                payment_methods,
                context: given_context,
                payer: current_processor_payer,
                collective: true
              )
            else
              record.processor(context: given_context, payer: current_processor_payer)
            end
        end

        def processor_action_name
          if action_name.to_s == "collective_processor_action"
            "collective_#{params[:processor_action]}"
          else
            params[:processor_action]
          end
        end

        def processor_action_arguments
          permitted_schema = processor.params_for(
            (params[:processor_action] || "action").to_sym,
            type: action_name.to_s == "collective_processor_action" ? :collective : nil
          )
          permitted = normalized_processor_request_params.permit(*permitted_schema)
          permitted = permitted.to_h.deep_symbolize_keys
          options = ::PaymentCore.config.payment_method.processor_action_params
          options = instance_exec(&options) if options.is_a?(Proc)
          options = (options || {}).merge(collective: action_name.to_s == "collective_processor_action")
          [permitted, given_context, options]
        end

        def perform_processor_action
          if skip_processor_action_access_validation?
            processor.perform(processor_action_name, *processor_action_arguments)
          else
            processor.perform_with_access(
              action_name: processor_action_name,
              accesses: processor_action_accesses,
              action_arguments: processor_action_arguments
            )
          end
        end

        def processor_action_accesses
          [:public]
        end

        def skip_processor_action_access_validation?
          false
        end

        def current_processor_payer
          respond_to?(:current_holder) ? current_holder : nil
        end

        def payables(payable_params = {})
          payable_params ||= {}
          Array(payable_params).inject([]) do |arr, (payable_type, ids)|
            arr + payable_class(payable_type).payable_api.finders(ids)
          end
        rescue StandardError
          raise ActiveRecord::RecordNotFound
        end

        def payable_class(payable_type)
          payable_type.safe_constantize ||
            ::PaymentCore::Models::Decorators::Payable.registered_classes.find do |klass|
              klass.payable_api.type == payable_type
            end ||
            raise(ActiveRecord::RecordNotFound)
        end

        def member_processor_actions_for(payment_method)
          processor = payment_method.processor(context: given_context, payer: current_processor_payer)
          filter_processor_actions(
            processor.class.methods_annotated_with(:single_action, true),
            processor,
            type: :single
          )
        end

        def collective_processor_actions_for(method_type, scope:)
          processor = collection_processor_for(method_type, scope: scope)
          filter_processor_actions(
            processor.class.methods_annotated_with(:collective_action, true),
            processor,
            type: :collective
          )
        end

        def processor_param_fields_for(processor, action_name, type: :single)
          schema = processor.params_for(action_name, type: type == :collective ? :collective : nil)
          normalize_processor_param_fields(schema)
        end

        def payable_type_options_for_select
          registered_payable_classes.map do |klass|
            [klass.payable_api.type.to_s.humanize, klass.payable_api.type.to_s]
          end
        end

        def payable_grouped_options_for_select
          registered_payable_classes.filter_map do |klass|
            records = if klass < ActiveRecord::Base
              klass.where.not(id: nil).limit(50)
            else
              []
            end
            next if records.blank?

            [
              klass.payable_api.type.to_s.humanize,
              records.map do |payable|
                [payable_option_label(payable), payable.id]
              end
            ]
          end
        end

        def payment_method_options_for_select(scope, method_type: nil)
          query = scope.respond_to?(:where) ? scope : Array(scope)
          query = query.where(method_type: method_type) if method_type.present? && query.respond_to?(:where)
          Array(query).map do |payment_method|
            ["##{payment_method.id} #{payment_method.display_name.presence || payment_method.method_type}", payment_method.id]
          end
        end

        def processor_field_input_name(field)
          segments = field[:full_name].to_s.split(".")
          head = segments.shift
          segments.inject(head.to_s) { |memo, segment| "#{memo}[#{segment}]" }
        end

        def collection_processor_for(method_type, scope:)
          payment_methods = scope.respond_to?(:where) ? scope.where(method_type: method_type) : Array(scope).select { |pm| pm.method_type.to_s == method_type.to_s }
          ::PaymentCore.config.payment_processor_registry.resolve(method_type).new(
            payment_methods,
            context: given_context,
            payer: current_processor_payer,
            collective: true
          )
        end

        private

        def registered_payment_method_classes
          ::PaymentCore::Models::Decorators::PaymentMethod::Object.registered_classes
            .select { |klass| klass.method_type.present? }
            .uniq { |klass| klass.method_type.to_s }
        end

        def registered_payable_classes
          ::PaymentCore::Models::Decorators::Payable.registered_classes
            .select { |klass| klass.respond_to?(:payable_api) }
            .uniq { |klass| klass.payable_api.type.to_s }
        end

        def normalized_processor_request_params
          source = params.to_unsafe_h.deep_dup
          normalize_json_param_keys!(source, processor.params_for((params[:processor_action] || "action").to_sym,
                                                                  type: action_name.to_s == "collective_processor_action" ? :collective : nil))
          ActionController::Parameters.new(source)
        end

        def normalize_json_param_keys!(hash, schema)
          Array(schema).each do |entry|
            next unless entry.is_a?(Hash)

            entry.each do |key, value|
              if value == {}
                json_key = "#{key}_json"
                if hash[json_key].present?
                  hash[key.to_s] = JSON.parse(hash[json_key])
                end
              elsif hash[key.to_s].is_a?(Hash)
                normalize_json_param_keys!(hash[key.to_s], value)
              end
            end
          end
        rescue JSON::ParserError
          nil
        end

        def filter_processor_actions(actions, processor, type:)
          Array(actions).map(&:to_sym).select do |action_name|
            action_allowed_for_current_context?(processor, action_name, type: type)
          end
        end

        def action_allowed_for_current_context?(processor, action_name, type:)
          return true if skip_processor_action_access_validation?

          annotations = processor.class.annotations_for(action_name.to_sym) || {}
          allowed = Array(annotations[:action_accesses]).compact.map(&:to_sym)

          if allowed.blank? && type == :collective
            base_name = action_name.to_s.delete_prefix("collective_").to_sym
            annotations = processor.class.annotations_for(base_name) || {}
            allowed = Array(annotations[:action_accesses]).compact.map(&:to_sym)
          end

          allowed.any? && (allowed & Array(processor_action_accesses).map(&:to_sym)).any?
        end

        def normalize_processor_param_fields(schema, prefix = nil)
          Array(schema).flat_map do |entry|
            case entry
            when Symbol, String
              [build_processor_param_field(entry.to_s, prefix: prefix)]
            when Hash
              entry.flat_map do |key, value|
                if value == {}
                  [build_processor_param_field(key.to_s, prefix: prefix, input: :json)]
                else
                  normalize_processor_param_fields(value, [prefix, key.to_s].compact.join("."))
                end
              end
            else
              []
            end
          end
        end

        def build_processor_param_field(name, prefix:, input: nil)
          full_name = [prefix, name].compact.join(".")
          explicit_input = input
          explicit_input ||= :checkbox if full_name == "accepted"
          explicit_input ||= :payable_type if name == "payable_type"
          explicit_input ||= :payable_id if name == "payable_id"

          {
            name: name,
            full_name: full_name,
            input: explicit_input || :text,
            label: full_name.humanize
          }
        end

        def payable_option_label(payable)
          number = payable.respond_to?(:payable_number) ? payable.payable_number : payable.id
          name = payable.respond_to?(:name) ? payable.name : payable.class.name.demodulize
          "##{number} #{name}"
        end

        def normalize_store_model_value(template, value)
          return value if value.nil?

          case template
          when TrueClass, FalseClass
            ActiveModel::Type::Boolean.new.cast(value)
          when Array
            normalize_array_value(value)
          when Hash
            normalize_json_value(value) || {}
          else
            parsed = normalize_json_value(value)
            parsed.nil? ? value : parsed
          end
        end

        def normalize_array_value(value)
          case value
          when Array
            value.flat_map { |item| normalize_array_value(item) }.reject(&:blank?)
          when String
            stripped = value.strip
            return [] if stripped.blank?

            parsed = normalize_json_value(stripped)
            return Array(parsed).flatten.compact if parsed

            stripped.split(/[\n,]/).map(&:strip).reject(&:blank?)
          else
            Array(value).reject(&:blank?)
          end
        end

        def normalize_json_value(value)
          return nil unless value.is_a?(String)

          stripped = value.strip
          return nil unless stripped.start_with?("{", "[")

          JSON.parse(stripped)
        rescue JSON::ParserError
          nil
        end

        def build_form_field(prefix:, name:, value:)
          input =
            case value
            when TrueClass, FalseClass
              :checkbox
            when Array
              :list
            when Hash
              :json
            else
              :text
            end

          {
            prefix: prefix,
            name: name,
            label: name.to_s.humanize,
            input: input,
            value: format_form_field_value(value)
          }
        end

        def format_form_field_value(value)
          case value
          when Array
            if value.all? { |item| item.is_a?(String) || item.is_a?(Numeric) || item == true || item == false }
              value.join(", ")
            else
              JSON.pretty_generate(value.map { |item| item.respond_to?(:attributes) ? item.attributes : item })
            end
          when Hash
            JSON.pretty_generate(value)
          when nil
            ""
          else
            value
          end
        end
      end
    end
  end
end
