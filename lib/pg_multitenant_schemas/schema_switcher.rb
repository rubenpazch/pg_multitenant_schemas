# frozen_string_literal: true

module PgMultitenantSchemas
  # Core schema switching functionality
  class SchemaSwitcher
    class << self
      # Initialize connection management
      def initialize_connection
        # This is called by the Railtie when Rails starts
        # No special initialization needed as we use the configured connection class
      end

      # Get the database connection from the configured connection class
      def connection
        connection_class = PgMultitenantSchemas.configuration.connection_class
        if connection_class.is_a?(String)
          Object.const_get(connection_class).connection
        else
          connection_class.connection
        end
      rescue StandardError => e
        raise ConnectionError, "Failed to get database connection: #{e.message}"
      end

      # Switches the search_path - supports both APIs for backward compatibility
      def switch_schema(conn_or_schema, schema = nil)
        if conn_or_schema.is_a?(String)
          # New API: switch_schema('schema_name')
          schema = conn_or_schema
          conn = connection
        else
          # Old API: switch_schema(conn, 'schema_name')
          conn = conn_or_schema
        end

        raise ArgumentError, "Schema name cannot be empty" if schema.nil? || schema.strip.empty?

        # Use simple quoting for PostgreSQL identifiers
        quoted_schema = "\"#{schema.gsub('"', '""')}\""
        execute_sql(conn, "SET search_path TO #{quoted_schema};")
      end

      # Reset to default schema - supports both APIs
      def reset_schema(conn = nil)
        conn ||= connection
        execute_sql(conn, "SET search_path TO public;")
      end

      # Create a new schema - supports both APIs
      def create_schema(conn_or_schema, schema_name = nil)
        if conn_or_schema.is_a?(String)
          # New API: create_schema('schema_name')
          schema_name = conn_or_schema
          conn = connection
        else
          # Old API: create_schema(conn, 'schema_name')
          conn = conn_or_schema
        end

        raise ArgumentError, "Schema name cannot be empty" if schema_name.nil? || schema_name.strip.empty?

        quoted_schema = "\"#{schema_name.gsub('"', '""')}\""
        execute_sql(conn, "CREATE SCHEMA IF NOT EXISTS #{quoted_schema};")
      end

      # Drop a schema - supports both APIs
      def drop_schema(conn_or_schema, schema_name_or_options = nil, cascade: true)
        if conn_or_schema.is_a?(String)
          # New API: drop_schema('schema_name', cascade: true)
          schema_name = conn_or_schema
          options = schema_name_or_options || {}
          cascade = options.fetch(:cascade, cascade)
          conn = connection
        else
          # Old API: drop_schema(conn, 'schema_name', cascade: true)
          conn = conn_or_schema
          schema_name = schema_name_or_options
        end

        raise ArgumentError, "Schema name cannot be empty" if schema_name.nil? || schema_name.strip.empty?

        cascade_option = cascade ? "CASCADE" : "RESTRICT"
        quoted_schema = "\"#{schema_name.gsub('"', '""')}\""
        execute_sql(conn, "DROP SCHEMA IF EXISTS #{quoted_schema} #{cascade_option};")
      end

      # Check if schema exists - supports both APIs
      def schema_exists?(conn_or_schema, schema_name = nil)
        if conn_or_schema.is_a?(String)
          # New API: schema_exists?('schema_name')
          schema_name = conn_or_schema
          conn = connection
        else
          # Old API: schema_exists?(conn, 'schema_name')
          conn = conn_or_schema
        end

        return false if schema_name.nil? || schema_name.strip.empty?

        result = execute_sql(conn, <<~SQL)
          SELECT EXISTS(
            SELECT 1 FROM information_schema.schemata#{" "}
            WHERE schema_name = '#{schema_name}'
          ) AS schema_exists
        SQL
        get_result_value(result, 0, 0) == "t"
      end

      # Get current schema - supports both APIs
      def current_schema(conn = nil)
        conn ||= connection
        result = execute_sql(conn, "SELECT current_schema()")
        get_result_value(result, 0, 0)
      end

      private

      # Execute SQL with Rails 8 compatibility
      def execute_sql(conn, sql)
        if conn.respond_to?(:execute)
          # Rails connection - use execute
          conn.execute(sql)
        else
          # Raw PG connection - use exec
          conn.exec(sql)
        end
      end

      # Get value from result with compatibility for different result types
      def get_result_value(result, row, col)
        if result.respond_to?(:getvalue)
          # PG::Result
          result.getvalue(row, col)
        else
          # ActiveRecord::Result
          result.rows[row][col]
        end
      end
    end
  end
end
