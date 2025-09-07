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

      # Switches the search_path to the specified schema
      def switch_schema(schema_name)
        raise ArgumentError, "Schema name cannot be empty" if schema_name.nil? || schema_name.strip.empty?

        conn = connection
        quoted_schema = "\"#{schema_name.gsub('"', '""')}\""
        execute_sql(conn, "SET search_path TO #{quoted_schema};")
      end

      # Reset to default schema
      def reset_schema
        conn = connection
        execute_sql(conn, "SET search_path TO public;")
      end

      # Create a new schema
      def create_schema(schema_name)
        raise ArgumentError, "Schema name cannot be empty" if schema_name.nil? || schema_name.strip.empty?

        conn = connection
        quoted_schema = "\"#{schema_name.gsub('"', '""')}\""
        execute_sql(conn, "CREATE SCHEMA IF NOT EXISTS #{quoted_schema};")
      end

      # Drop a schema
      def drop_schema(schema_name, cascade: true)
        raise ArgumentError, "Schema name cannot be empty" if schema_name.nil? || schema_name.strip.empty?

        conn = connection
        cascade_option = cascade ? "CASCADE" : "RESTRICT"
        quoted_schema = "\"#{schema_name.gsub('"', '""')}\""
        execute_sql(conn, "DROP SCHEMA IF EXISTS #{quoted_schema} #{cascade_option};")
      end

      # Check if schema exists
      def schema_exists?(schema_name)
        return false if schema_name.nil? || schema_name.strip.empty?

        conn = connection
        result = execute_sql(conn, <<~SQL)
          SELECT EXISTS(
            SELECT 1 FROM information_schema.schemata#{" "}
            WHERE schema_name = '#{schema_name}'
          ) AS schema_exists
        SQL

        value = get_result_value(result, 0, 0)
        # Handle both boolean values and string representations
        case value
        when true, "t", "true"
          true
        when false, "f", "false"
          false
        else
          false
        end
      end

      # Get current schema
      def current_schema
        conn = connection
        result = execute_sql(conn, "SELECT current_schema()")
        get_result_value(result, 0, 0)
      end

      private

      # Execute SQL - handles both Rails connections and raw PG connections
      def execute_sql(conn, sql)
        if conn.respond_to?(:execute)
          # Rails/ActiveRecord connection
          conn.execute(sql)
        elsif conn.respond_to?(:exec)
          # Raw PG::Connection
          conn.exec(sql)
        else
          raise ArgumentError, "Connection must respond to either :execute or :exec"
        end
      end

      # Get value from result - handles both Rails and PG results
      def get_result_value(result, row, col)
        if result.respond_to?(:rows)
          # Rails ActiveRecord::Result
          result.rows[row][col]
        elsif result.respond_to?(:getvalue)
          # Raw PG::Result
          result.getvalue(row, col)
        elsif result.respond_to?(:[])
          # Alternative PG::Result access
          result[row][col]
        else
          raise ArgumentError, "Result must respond to either :rows, :getvalue, or :[]"
        end
      end
    end
  end
end
