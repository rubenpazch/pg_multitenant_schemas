# frozen_string_literal: true

module PgMultitenantSchemas
  # Exception classes
  class Error < StandardError; end
  class ConnectionError < Error; end
  class SchemaExists < Error; end
  class SchemaNotFound < Error; end
  class ConfigurationError < Error; end
  class TenantNotFound < Error; end
end
