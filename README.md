# PaymentCore

`PaymentCore` is a Rails engine for modeling payment methods, payment transactions, payment intents, and the processor behavior that connects them.

It gives you:

- core persistence models for payment methods, entries, and payment intents
- a processor DSL that maps `method_type` to executable payment behavior
- a lib-based Grape API layer for admin, holder-scoped, and webhook payment flows
- extension points for traits, callbacks, metadata, presenters, and API resource configuration

`payment_core` is designed to be expanded from the application. The engine supplies the base models and plumbing; the application decides which payment-method subclasses exist, which processors execute them, which holder and payable models participate, and which API or presenter overrides should be applied.

## What Problem This Solves

Use this engine when your app needs both of these at the same time:

- reusable payment method records such as cash, bank transfer, or gateway-backed methods
- a structured action layer that can capture, charge, validate, or handle webhooks differently per method type

Why this matters:

- a payment method record answers "what payment option is available?"
- a processor answers "what can this payment option do?"
- an entry answers "what payment transaction actually happened?"
- a payment intent answers "what staged payment state exists before or around that transaction?"

If you only store a generic payment record, you lose the distinction between method configuration and method behavior. `PaymentCore` restores that separation and keeps the behavior aligned with the method type.

## How The Engine Works

The engine revolves around four concepts:

- `payment method`
- `entry`
- `payment intent`
- `processor`

At the base level:

- `PaymentCore::PaymentMethod` stores reusable payment method configuration
- `PaymentCore::Entry` stores the payment transaction record
- `PaymentCore::PaymentIntent` stores staged or intent-level payment state
- `PaymentCore::Processors::*` classes implement supported actions for a payment method type

Example:

```ruby
payment_method = PaymentCore::PaymentMethods::Cash.first
processor = payment_method.processor

processor.perform(:charge, params, context)
```

This is the low-level interface:

- the payment method carries the method type and method configuration
- the processor carries the executable actions
- the entry is the transaction record that gets created or updated by the flow
- the intent is the staged state that can expire, confirm, or constrain entry execution

When you define a payment method subclass, the engine registers it and exposes it through relations, API resource configuration, and processor lookup.

Example:

```ruby
module PaymentCore
  module PaymentMethods
    class Cash < ::PaymentCore::PaymentMethod
    end
  end
end
```

When you define a processor subclass, the engine uses its class name as the default `method_type` and registers it into the payment processor registry.

Example:

```ruby
module PaymentCore
  module Processors
    class Cash < ::PaymentCore::Processors::Base
      action :charge do |params, context|
        # processor behavior
      end
    end
  end
end
```

`Cash` is meaningful because it gives the `cash` method type an executable class-level definition. The engine uses that to route actions such as:

- single actions like `charge`
- collective actions such as `collective_charge`
- webhook actions such as `webhook_capture`

So a processor subclass does not just mean "another service object". It is the structured version of executable payment behavior for a registered payment method type.

## Extending And Renaming Payment Behavior

The extension surface is not only "add a subclass". Host apps can keep engine defaults, or they can override the names, traits, callbacks, and API resource config the engine uses when they want a stronger payment API.

Think about the application API in two layers:

- defaults: what the engine will infer from class names, `method_type`, `payment_method_name`, processor actions, presenters, and resource contexts
- overrides: what you redefine when you want the payment API to read like your domain instead of the raw engine naming

For payment methods, the main extension hooks are:

- `self.method_type = ...`
- `self.payment_method_name = ...`
- `allows_entry_type`
- `requires_payable!`
- `entry_method_data_defaults`
- payment-method traits such as `credentials`, `expirable`, `reusable`, `refundable`, `withdrawable`, and `intent_driven`
- `grape_api_resource` / `api_resource`

For processors, the main extension hooks are:

- `self.method_type = ...`
- `action`, `single_action`, `collective_action`, `webhook_action`
- `action_access`
- `params`
- `validate_payment_method`

Example:

```ruby
module PaymentCore
  module PaymentMethods
    class BankTransfer < ::PaymentCore::PaymentMethod
      self.method_type = "bank_transfer"
      self.payment_method_name = "bank_transfer"

      intent_driven
      allows_entry_type "charge"
    end
  end

  module Processors
    class BankTransfer < ::PaymentCore::Processors::Base
      self.method_type = "bank_transfer"

      action :charge do |params, context|
        # custom charge flow
      end

      action_access :charge, :public
    end
  end
end
```

With overrides like these, the application can shape:

- which entry types a payment method accepts
- whether a payable is required
- whether the method is intent-driven, reusable, refundable, or credential-backed
- which processor actions are exposed publicly, privately, or by webhook
- how a payment method should be presented through API resource contexts

## Installation

Add the engine to the application:

```ruby
gem "payment_core", path: "engines/payment_core"
```

Install the engine, generate the engine files, and migrate:

```bash
bundle install
bin/rails payment_core:install
bin/rails generate payment_core:config
bin/rails db:migrate
```

If you want the Rails engine routes available, mount it explicitly:

```ruby
# config/routes.rb
mount PaymentCore::Engine => "/payment_core"
```

If you expose the Grape API, mount that explicitly in the application as well.

## What The Engine Ships

Persistent model classes:

- `PaymentCore::PaymentMethod`
- `PaymentCore::Entry`
- `PaymentCore::PaymentIntent`

Decorator namespaces:

- `PaymentCore::Models::Decorators::PaymentMethod::Object`
- `PaymentCore::Models::Decorators::Entry::Object`
- `PaymentCore::Models::Decorators::PaymentIntent::Object`
- payable and payment-method-holder decorators under `PaymentCore::Models::Decorators`

Processor layer:

- `PaymentCore::Processors::Base`
- built-in processors such as `Cash`, `BankTransfer`, and `Fiuu`
- the `PaymentCore::Processors::Object` DSL for `action`, `collective_action`, `webhook_action`, `action_access`, `params`, and `validate_payment_method`

Grape API entrypoints:

- `PaymentCore::Grape::Base`
- `PaymentCore::Grape::Admin::Base`
- `PaymentCore::Grape::Holder::Base`
- `PaymentCore::Grape::Webhooks`

Grape resource classes:

- `PaymentCore::Grape::Resources::PaymentMethods`
- `PaymentCore::Grape::Resources::Entries`

Presenter classes:

- `PaymentCore::Grape::Presenters::PaymentMethod`
- `PaymentCore::Grape::Presenters::Entry`
- `PaymentCore::Grape::Presenters::PaymentIntent`
- payable, holder, and reference presenters under `PaymentCore::Grape::Presenters`

## Core Model Design

The base models are intentionally thin:

- [app/models/payment_core/payment_method.rb](/home/ihsan/Works/VirtualSpirit/Ruby/engines/payment_core/app/models/payment_core/payment_method.rb)
- [app/models/payment_core/entry.rb](/home/ihsan/Works/VirtualSpirit/Ruby/engines/payment_core/app/models/payment_core/entry.rb)
- [app/models/payment_core/payment_intent.rb](/home/ihsan/Works/VirtualSpirit/Ruby/engines/payment_core/app/models/payment_core/payment_intent.rb)

Most real behavior is injected by the decorator objects under `lib/payment_core/models/decorators`.

### `PaymentCore::PaymentMethod`

When `PaymentCore::Models::Decorators::PaymentMethod::Object` is included, the class gets:

- payment-method registration by subclass and `method_type`
- metadata and availability-rules custom-attribute models
- holder, reference, and entry relation setup
- event publication on create, update, save, and destroy
- `entry_callback` hooks that register behavior onto entry classes
- `grape_api_resource "payment_core", default: true` metadata and presenter defaults
- payment-method configuration such as allowed entry types, direction, and payable requirements

In practice this means the payment-method class is the reusable configuration layer for payment execution.

### `PaymentCore::Entry`

When `PaymentCore::Models::Decorators::Entry::Object` is included, the class gets:

- payment-entry registration by subclass and `entry_type`
- payment-method and payment-intent relation hooks
- metadata custom attributes
- idempotency locking, thread-safety, and transaction-root tracking
- state-machine behavior for payment lifecycle transitions
- event publication on lifecycle and state changes
- wrapper support for grouped or composite entry flows
- API resource support through `ApiResource`

In practice this means the entry class is the durable transaction record for payment execution.

### `PaymentCore::PaymentIntent`

When `PaymentCore::Models::Decorators::PaymentIntent::Object` is included, the class gets:

- payment-intent registration by subclass and `intent_name`
- payable and entry relation hooks
- metadata custom attributes
- idempotency locking, thread-safety, and transaction-root tracking
- a state machine for `pending`, `confirmed`, `expired`, and `canceled`
- expiration scheduling and late-success event handling
- `entry_callback` hooks that can constrain entry execution when an intent expires

In practice this means the intent class is the staged or pre-transaction layer around entry execution.

## Root App Expansion Model

The engine is built so the application expands it in four layers:

1. Register application models as payment-method holders or payables where needed.
2. Create subclasses of `PaymentCore::PaymentMethod`, `PaymentCore::Entry`, and `PaymentCore::PaymentIntent` where needed.
3. Create processor subclasses that match the payment-method `method_type`.
4. Add traits, callbacks, API resource overrides, and presenters on those subclasses.

### 1. Register Root-App Holder And Payable Models

`payment_core` is not useful in isolation. An application usually connects it to models that can hold payment methods or act as payables.

The dummy app shows this integration style through app models such as:

- `Order`
- `LineItem`
- `Product`
- `User`

and payment-specific behavior wired through subscribers and application extensions.

### 2. Create Root-App Payment Classes

The decorator objects automatically register subclasses of `PaymentCore::PaymentMethod`, `PaymentCore::Entry`, and `PaymentCore::PaymentIntent`.

That registration matters because:

- payment-method subclasses become resolvable by `method_type`
- entry subclasses become available to entry callbacks and relation hooks
- payment-intent subclasses become available to payable and entry relation hooks
- Grape helpers resolve model classes through the configured payment resource metadata

Example:

```ruby
module PaymentCore
  module PaymentMethods
    class PaymentPackage < ::PaymentCore::PaymentMethod
    end
  end
end
```

### 3. Create Matching Processor Subclasses

A payment-method subclass is only the configuration half. The executable half is the matching processor subclass.

The dummy app shows the intended pattern:

```ruby
module PaymentCore
  module Processors
    class PaymentPackage < ::PaymentCore::Processors::Base
      action :charge do |params, context|
        # processor behavior
      end

      collective_action :charge do |params, context|
        # collective behavior
      end
    end
  end
end
```

What the processor DSL adds:

- `action` / `single_action` for direct payment-method actions
- `collective_action` for group flows
- `webhook_action` for gateway callbacks
- `action_access` for public, private, admin, or webhook access control
- `params` for route-level permitted parameter declarations
- `validate_payment_method` for method-specific validation before execution

### 4. Add Traits, Callbacks, And API Overrides

Once the application has its own payment-method or processor subclass, it can add domain behavior without rewriting the engine.

Common extension points are:

- payment-method traits such as credentials, expirable, reusable, refundable, withdrawable, or intent-driven behavior
- `entry_callback` hooks on payment methods and payment intents
- processor action access annotations
- `grape_api_resource` / `api_resource` overrides on application subclasses

Example:

```ruby
class AppPaymentMethod < PaymentCore::PaymentMethod
  grape_api_resource "app", from: "payment_core" do
    presenter "App::Grape::Presenters::PaymentMethod"
  end
end
```

### What Traits And Callbacks Actually Change

The extensibility surface is defined by what each layer is allowed to change.

- payment-method traits can patch metadata, credentials, expiry rules, reuse rules, refundability, withdrawal support, and intent-driven behavior
- payment-method `entry_callback` hooks can inject validation, after-create, and after-save behavior into registered entry classes
- payment-intent `entry_callback` hooks can constrain whether entries are allowed to succeed or expire
- processor annotations can change which actions exist, what params they accept, and which access surfaces can call them
- API resource overrides can keep the engine defaults while replacing only presenter, finder, path, params, or action config

That is the reason the engine uses decorators, traits, and annotated processor methods instead of only plain subclasses.

## Traits

Traits are how you add reusable payment-method behavior without bloating the base engine model or duplicating the same callback and metadata logic across multiple payment-method subclasses.

The key pattern in this engine is:

- define a trait module under `lib/payment_core/models/decorators/payment_method/...`
- have that trait extend `PaymentCore::Models::Decorators::PaymentMethod::Object`
- expose a class method that configures the trait on a payment-method subclass
- patch metadata, validations, callbacks, or helper methods from that class method
- apply the trait by calling the class method on the target payment-method class

Do not treat traits as plain `include` modules. In this engine, traits are intended to be activated by class methods on the target model.

### Built-In Payment-Method Traits

The engine already ships several payment-method trait modules:

- `credentials`
  - patches metadata attributes with encrypted credential fields
  - validates required credential presence
  - removes those credential fields from `as_json`

- `expirable`
  - validates `expires_at`
  - can require expiry timestamps through config
  - adds expiry-aware `active` / `expired?` behavior

- `intent_driven`
  - patches metadata with `require_intent`
  - validates that a usable payment intent exists when required
  - updates intent expiry and confirmation behavior from entry callbacks

- `refundable`
  - enables the `refund` entry type

- `withdrawable`
  - enables the `withdraw` entry type

- `uses_reference`
  - requires and validates a payment-method reference
  - can synchronize reference attributes onto the payment method

- `reusable`
  - exists as a trait surface, but is not yet fully implemented

### Example: `intent_driven`

`intent_driven` is a good example of what a payment-method trait is supposed to do.

It:

- defines a config object through `intent_driven_config`
- patches the payment-method metadata model
- adds helper methods like `require_intent?`
- registers entry validations and after-save callbacks onto entry classes
- changes how payment intents and entries interact during execution

Applied usage looks like this:

```ruby
module PaymentCore
  module PaymentMethods
    class Fiuu < ::PaymentCore::PaymentMethod
      intent_driven
    end
  end
end
```

### Trait Authoring Pattern

If the application wants a new payment-method trait, follow the same shape as `intent_driven` or `uses_reference`:

1. Create a module under `lib/payment_core/models/decorators/payment_method/...`.
2. Extend `Plugins::Decorators::ConfigBuilder` if the trait needs its own config object.
3. Extend `PaymentCore::Models::Decorators::PaymentMethod::Object`.
4. Expose a class method that configures the trait on the target model.
5. Patch metadata, validations, callbacks, helper methods, or entry behavior from that method.

### Custom Trait Example

Example: an application wants a `risk_gate` trait that forces a payment-method entry through additional validation and marks metadata for gated payment flows.

```ruby
module PaymentCore
  module Models
    module Decorators
      module PaymentMethod
        module RiskGate
          extend Plugins::Decorators::ConfigBuilder

          module Metadata
            extend ActiveSupport::Concern

            included do
              attribute :requires_risk_gate, :boolean, default: true
            end
          end

          def self.included(base)
            invalid_class?(base)
            base.extend ClassMethods
          end

          module ClassMethods
            def risk_gate(**opts, &block)
              default_opts = { default: true }
              config_class.setup(self, "risk_gate_config", opts, default_opts, &block)

              metadata_class = patch_store_model_class!(
                base: store_model_klass_of(:metadata),
                mod: Metadata,
                name: :RiskGateMetadata
              )
              define_metadata_class(metadata_class)

              define_inheritable_singleton_method(:risk_gate?) { true }

              entry_callback :validate do |entry|
                if metadata.requires_risk_gate && entry.amount.to_d > 1_000
                  entry.errors.add(:base, :requires_risk_gate)
                end
              end

              include InstanceMethods
            end

            def risk_gate?
              false
            end
          end

          module InstanceMethods
            def requires_risk_gate?
              metadata.requires_risk_gate
            end
          end

          extend ::PaymentCore::Models::Decorators::PaymentMethod::Object
        end
      end
    end
  end
end
```

Applied usage:

```ruby
  module PaymentCore
  module PaymentMethods
    class OfflineInvoice < ::PaymentCore::PaymentMethod
      risk_gate do
        default false
      end
    end
  end
end
```

The same trait-style pattern also appears on entry and payment-intent decorator namespaces, even when the concrete extension mechanism is callback-heavy rather than a named DSL trait.

## Configuration

The engine configuration extends `Plugins::Configuration::Core` and adds payment-specific setup points.

Main configuration areas:

- `PaymentCore.config.payment_method`
- `PaymentCore.config.payment_entry`
- `PaymentCore.config.payment_intent`
- `PaymentCore.config.payment_processor_registry`
- `PaymentCore.config.api`
- `PaymentCore.config.grape_api`

Important `payment_method` configuration hooks include:

- `metadata_base_class`
- `availability_rules_class`
- `availability_context_class`
- `availabilty_matcher_class`
- `default_payment_methods_builder`
- `default_context_builder`
- `processor_action_params`
- `processor_webhook_action_params`
- `credentials_encryption_key`
- `webhook_sla_seconds`

Example:

```ruby
PaymentCore.config.payment_method do
  credentials_encryption_key { Rails.application.credentials.secret_key_base }
  webhook_sla_seconds 7_200
end
```

The `payment_entry` and `payment_intent` config modules expose metadata base classes in the same pattern, so applications can plug in typed metadata without replacing the core models.

## Grape API Routes

`PaymentCore::Grape::Base.draw` mounts these namespaces by default:

- `admin`
- `holder`
- `webhooks`

### Admin surface

The admin API exposes payment-method and entry management routes, including processor actions.

Default route shapes:

- `GET /admin/:payment_method_name`
- `POST /admin/:payment_method_name`
- `GET /admin/:payment_method_name/:id`
- `PUT /admin/:payment_method_name/:id`
- `POST /admin/:payment_method_name/:method_type/:processor_action`
- `POST /admin/:payment_method_name/:id/:processor_action`
- `GET /admin/entries`
- `GET /admin/entry/:id`

### Holder surface

The holder API exposes payment methods and entries scoped to a holder record.

Default route shapes:

- `GET /holder/:holder_type/:holder_id/payment_methods`
- `GET /holder/:holder_type/:holder_id/payment_methods/available`
- `GET /holder/:holder_type/:holder_id/entry`
- `GET /holder/:holder_type/:holder_id/entry/:id`

### Webhook surface

The webhook API exposes gateway callback routes by gateway type.

Default route shapes:

- `GET /webhook/:gateway_type`
- `POST /webhook/:gateway_type`
- `PUT /webhook/:gateway_type`

Mount the engine in a host Grape API like this:

```ruby
module Api
  class Base < Grape::API
    mount ::PaymentCore::Grape::Base.draw
  end
end
```

You can also mount it under a custom namespace:

```ruby
module Api
  class Payments < Api::Base
    mount(::PaymentCore::Grape::Base.draw(namespace: :payments))
  end
end
```

Example resulting route:

- `GET /payments/admin/entries`

## Dummy-App Integration Examples

The dummy app demonstrates one integration where payment methods, processors, subscribers, and application models are wired together.

Reference files:

- [spec/dummy/lib/payment_core/payment_methods/payment_package.rb](/home/ihsan/Works/VirtualSpirit/Ruby/engines/payment_core/spec/dummy/lib/payment_core/payment_methods/payment_package.rb)
- [spec/dummy/lib/payment_core/processors/payment_package.rb](/home/ihsan/Works/VirtualSpirit/Ruby/engines/payment_core/spec/dummy/lib/payment_core/processors/payment_package.rb)
- [spec/dummy/lib/payment_core/attributes/entries/method_data/payment_package_method.rb](/home/ihsan/Works/VirtualSpirit/Ruby/engines/payment_core/spec/dummy/lib/payment_core/attributes/entries/method_data/payment_package_method.rb)

What the dummy app demonstrates:

- an application payment-method subclass can add extra validations and entry callbacks
- a matching processor can declare public and collective actions
- payment-method-specific method-data classes can shape entry metadata
- application subscribers can react to payment lifecycle events without patching the engine

Those are dummy-app integration examples, not default behavior required by every application.

## Callback And Event Extension Points

The decorators expose several application extension points.

### Payment-method callbacks onto entries

Payment-method classes can register callbacks onto all entry classes via:

- `entry_callback`

Common built-in uses include:

- availability validation
- payable-required validation
- allowed-entry-type validation
- `last_used_at` updates after save

### Payment-intent callbacks onto entries

Payment-intent classes can also register callbacks onto entry classes via:

- `entry_callback`

The base implementation already uses this to prevent successful execution against expired intents and to publish a `late_success` event when needed.

### Processor action access control

Processor classes can annotate access rules onto actions via:

- `action_access`
- `remove_action_access`

This is how the engine keeps admin, public, holder, private, and webhook execution paths separate without hardcoding all access logic inside controllers.

### Event publication

The base models publish lifecycle events through the Plugins eventable stack:

- payment methods publish create, update, save, and destroy events
- entries publish lifecycle and state-change events
- payment intents publish lifecycle and state-change events

Root apps can subscribe to those flows in local subscribers instead of modifying engine internals.

## Notes

- The engine follows the thin-model + decorator-object pattern.
- Processor behavior should stay aligned with `method_type` registration to avoid registry mismatches.
- `PaymentCore::Grape::Base.draw` is the main mount surface for applications.
- Payment method credentials should be configured through `PaymentCore.config.payment_method.credentials_encryption_key`.
- Root apps can inherit `payment_core` API resource definitions and override them with `from:`.

## Contributing

Bug reports and pull requests are welcome.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
