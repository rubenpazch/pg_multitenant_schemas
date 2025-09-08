#!/bin/bash
# Test GitHub Actions permissions and setup locally

echo "🔍 Testing GitHub Actions setup and permissions..."
echo ""

# Check if we're in a Git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "❌ Not in a Git repository"
    exit 1
fi

# Check if we're on the right branch
current_branch=$(git branch --show-current)
echo "📋 Current branch: $current_branch"

# Check if we have the workflow files
if [ -f ".github/workflows/main.yml" ]; then
    echo "✅ CI workflow file exists"
else
    echo "❌ CI workflow file missing"
fi

if [ -f ".github/workflows/release.yml" ]; then
    echo "✅ Release workflow file exists"
else
    echo "❌ Release workflow file missing"
fi

# Check version file
if [ -f "lib/pg_multitenant_schemas/version.rb" ]; then
    version=$(grep -E "VERSION = ['\"]" lib/pg_multitenant_schemas/version.rb | cut -d'"' -f2 | cut -d"'" -f2)
    echo "✅ Version file exists: $version"
else
    echo "❌ Version file missing"
fi

# Check if gemspec exists
if [ -f "pg_multitenant_schemas.gemspec" ]; then
    echo "✅ Gemspec file exists"
else
    echo "❌ Gemspec file missing"
fi

# Check remote origin
remote_url=$(git remote get-url origin 2>/dev/null || echo "No remote")
echo "📋 Remote origin: $remote_url"

# Test Git config (what GitHub Actions would use)
echo ""
echo "🧪 Testing Git configuration..."
git config --local user.email "41898282+github-actions[bot]@users.noreply.github.com"
git config --local user.name "github-actions[bot]"
echo "✅ Git config set for GitHub Actions bot"

# Test gem build
echo ""
echo "🧪 Testing gem build..."
if gem build pg_multitenant_schemas.gemspec > /dev/null 2>&1; then
    echo "✅ Gem builds successfully"
    rm -f pg_multitenant_schemas-*.gem
else
    echo "❌ Gem build failed"
fi

# Check for uncommitted changes
if [ -n "$(git status --porcelain)" ]; then
    echo ""
    echo "⚠️  You have uncommitted changes:"
    git status --short
fi

echo ""
echo "🎯 Next Steps:"
echo "1. Ensure repository has proper permissions set in GitHub:"
echo "   - Go to Settings > Actions > General"
echo "   - Set 'Workflow permissions' to 'Read and write permissions'"
echo "   - Enable 'Allow GitHub Actions to create and approve pull requests'"
echo ""
echo "2. To trigger a release:"
echo "   - Update version in lib/pg_multitenant_schemas/version.rb"
echo "   - Commit and push to main branch"
echo "   - GitHub Actions will automatically create a release"
echo ""
echo "📚 For more details, see: docs/github_actions_setup.md"
