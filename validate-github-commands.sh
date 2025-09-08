#!/bin/bash
# Validate GitHub workflow commands locally
# This script tests the exact commands used in GitHub Actions

set -e

echo "🧪 Testing GitHub Actions commands locally..."
echo ""

# Test RuboCop (exact command from workflow)
echo "📋 Testing: bundle exec rubocop"
if bundle exec rubocop > /dev/null 2>&1; then
    echo "✅ RuboCop passed"
else
    echo "❌ RuboCop failed"
    exit 1
fi

# Test unit tests (exact command from workflow) 
echo "📋 Testing: bundle exec rspec --exclude-pattern '**/integration/**/*_spec.rb'"
if bundle exec rspec --exclude-pattern '**/integration/**/*_spec.rb' > /dev/null 2>&1; then
    echo "✅ Unit tests passed"
else
    echo "❌ Unit tests failed"
    exit 1
fi

# Test integration tests (exact command from workflow)
echo "📋 Testing: bundle exec rspec --tag integration"
if bundle exec rspec --tag integration > /dev/null 2>&1; then
    echo "✅ Integration tests passed"
else
    echo "⚠️  Integration tests failed (may need PostgreSQL setup)"
fi

# Test security audit (exact command from workflow)
echo "📋 Testing: bundle audit"
if bundle audit > /dev/null 2>&1; then
    echo "✅ Security audit passed"
else
    echo "⚠️  Security audit failed (may have vulnerabilities)"
fi

echo ""
echo "🎉 GitHub Actions command validation complete!"
echo ""
echo "💡 These are the exact commands that run in GitHub Actions CI"
