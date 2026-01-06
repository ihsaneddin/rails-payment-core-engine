require "rails/generators/active_record"
require "active_record"

module PaymentCore
  module Generators
    class InstallGenerator < ::Rails::Generators::Base
      include ActiveRecord::Generators::Migration
      source_root File.join(__dir__, "templates")

      class_option :uuid, type: :boolean, default: false

      def copy_migration
        if uuid?
          migration_template "migration_uuid.rb", "db/migrate/create_payment_core_tables.rb", migration_version: migration_version
        else
          migration_template "migration.rb", "db/migrate/create_payment_core_tables.rb", migration_version: migration_version
        end
      end

      def migration_version
        "[#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}]"
      end

      def uuid?
        options[:uuid]
      end

    end
  end
end