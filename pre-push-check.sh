#!/bin/bash
# Pre-push check script for pg_multitenant_schemas gem
# Run this before pushing to GitHub to catch issues early

set -e  # Exit on any error

echo "🔍 Running pre-push checks for pg_multitenant_schemas..."
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${2}${1}${NC}"
}

# Function to run a check
run_check() {
    local name="$1"
    local command="$2"
    local optional="$3"
    
    echo "📋 $name..."
    if eval "$command"; then
        print_status "✅ $name passed" "$GREEN"
    else
        if [ "$optional" = "true" ]; then
            print_status "⚠️  $name failed (optional)" "$YELLOW"
        else
            print_status "❌ $name failed" "$RED"
            exit 1
        fi
    fi
    echo ""
}

# 1. Check if we're in the right directory
if [ ! -f "pg_multitenant_schemas.gemspec" ]; then
    print_status "❌ Not in pg_multitenant_schemas directory" "$RED"
    exit 1
fi

# 2. Install dependencies
run_check "Bundle install" "bundle install --quiet"

# 3. RuboCop
run_check "RuboCop (code style)" "bundle exec rubocop"

# 4. RSpec unit tests
run_check "RSpec unit tests" "bundle exec rspec --exclude-pattern '**/integration/**/*_spec.rb'"

# 5. Security audit
run_check "Security audit" "bundle audit" "true"

# 6. Gem build test
run_check "Gem build test" "gem build pg_multitenant_schemas.gemspec > /dev/null 2>&1 && rm -f pg_multitenant_schemas-*.gem"

# 7. Check for PostgreSQL and run integration tests
if command -v psql &> /dev/null && pg_isready &> /dev/null; then
    # Check if test database exists, create if not
    if ! psql -lqt | cut -d \| -f 1 | grep -qw pg_multitenant_test; then
        echo "📋 Creating test database..."
        createdb pg_multitenant_test || true
    fi
    
    run_check "Integration tests" "PGDATABASE=pg_multitenant_test bundle exec rspec --tag integration" "true"
else
    print_status "⚠️  PostgreSQL not available, skipping integration tests" "$YELLOW"
fi

# 8. Check for uncommitted changes
if [ -n "$(git status --porcelain)" ]; then
    print_status "⚠️  You have uncommitted changes" "$YELLOW"
    git status --short
    echo ""
fi

# 9. Check current branch
current_branch=$(git branch --show-current)
if [ "$current_branch" = "main" ]; then
    print_status "⚠️  You're on the main branch" "$YELLOW"
fi

echo "🎉 All checks completed successfully!"
echo ""
echo "🚀 Your code is ready to push to GitHub!"
echo ""
echo "💡 Pro tip: You can test GitHub Actions locally using 'act':"
echo "   brew install act"
echo "   act push  # Test CI workflow"
echo ""
