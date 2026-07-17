#!/bin/bash

# Pre-Release Checklist for PgMultitenantSchemas

set -e

echo "🚀 PgMultitenantSchemas Release Preparation"
echo "==========================================="
echo ""

# Check git status
echo "📋 Checking git status..."
git status

echo ""
echo "✅ Pre-Release Checklist"
echo "======================="
echo ""

# Run tests
echo "🧪 Running test suite..."
bundle exec rspec --format=progress 2>&1 | tail -3
echo ""

# Check for any syntax errors
echo "🔍 Checking for syntax errors..."
bundle exec ruby -c lib/pg_multitenant_schemas.rb > /dev/null && echo "✅ Main module OK"
bundle exec ruby -c lib/pg_multitenant_schemas/context.rb > /dev/null && echo "✅ Context module OK"
bundle exec ruby -c lib/pg_multitenant_schemas/schema_switcher.rb > /dev/null && echo "✅ SchemaSwitcher module OK"
echo ""

# Check version
echo "📌 Current version:"
grep "VERSION = " lib/pg_multitenant_schemas/version.rb
echo ""

echo "✨ Release checklist completed!"
echo ""
echo "📝 Next steps:"
echo "1. Review changes: git diff"
echo "2. Stage changes: git add ."
echo "3. Commit: git commit -m 'Release v0.3.0'"
echo "4. Create tag: git tag -a v0.3.0 -m 'Release v0.3.0'"
echo "5. Push: git push && git push --tags"
echo "6. Build gem: gem build pg_multitenant_schemas.gemspec"
echo "7. Push to RubyGems: gem push pg_multitenant_schemas-0.3.0.gem"
