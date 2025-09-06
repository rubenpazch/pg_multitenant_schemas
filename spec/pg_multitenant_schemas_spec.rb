# frozen_string_literal: true

RSpec.describe PgMultitenantSchemas do
  it "has a version number" do
    expect(PgMultitenantSchemas::VERSION).not_to be_nil
  end

  it "provides schema switching functionality" do
    expect(PgMultitenantSchemas::SchemaSwitcher).to respond_to(:switch_schema)
    expect(PgMultitenantSchemas::SchemaSwitcher).to respond_to(:reset_schema)
    expect(PgMultitenantSchemas::SchemaSwitcher).to respond_to(:create_schema)
    expect(PgMultitenantSchemas::SchemaSwitcher).to respond_to(:drop_schema)
  end
end
