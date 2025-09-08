# Testing GitHub Workflows Locally

This guide shows you how to test GitHub Actions workflows locally before pushing to GitHub.

## 🚀 Method 1: Using `act` (Recommended)

`act` is the most popular tool for running GitHub Actions locally using Docker.

### Installation

```bash
# macOS (using Homebrew)
brew install act

# Linux (using curl)
curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash

# Windows (using Chocolatey)
choco install act-cli
```

### Basic Usage

```bash
# List all workflows
act -l

# Run all workflows
act

# Run specific workflow
act push

# Run specific job
act -j test

# Run with specific event
act pull_request

# Dry run (show what would be executed)
act -n
```

### Testing Our Workflows

```bash
# Test the main CI workflow
act push

# Test the release workflow (simulates a push to main)
act push --env GITHUB_REF=refs/heads/main

# Test pull request workflow
act pull_request
```

### Configuration

Create `.actrc` file in project root for default settings:

```bash
# .actrc
--container-architecture linux/amd64
--artifact-server-path /tmp/act-artifacts
--env-file .env.local
```

### Environment Variables

Create `.env.local` for local testing:

```bash
# .env.local
GITHUB_TOKEN=your_github_token_here
RUBYGEMS_API_KEY=your_rubygems_key_here
GITHUB_REPOSITORY=rubenpazch/pg_multitenant_schemas
GITHUB_ACTOR=your_username
```

## 🔧 Method 2: Manual Testing Components

### Test RuboCop Locally

```bash
# Run RuboCop (same as in CI)
bundle exec rubocop

# Auto-fix issues
bundle exec rubocop -A

# Check specific files
bundle exec rubocop lib/ spec/
```

### Test RSpec Locally

```bash
# Run all tests
bundle exec rspec

# Run with coverage (if configured)
COVERAGE=true bundle exec rspec

# Run integration tests
bundle exec rspec --tag integration

# Run tests with different Ruby versions (using rbenv/rvm)
rbenv shell 3.2.0 && bundle exec rspec
rbenv shell 3.3.0 && bundle exec rspec
```

### Test Gem Building

```bash
# Build gem locally
gem build pg_multitenant_schemas.gemspec

# Install locally built gem
gem install pg_multitenant_schemas-*.gem

# Test gem installation
gem list | grep pg_multitenant_schemas
```

### Test PostgreSQL Setup

```bash
# Start PostgreSQL (macOS with Homebrew)
brew services start postgresql@15

# Create test database
createdb pg_multitenant_test

# Run integration tests
PGDATABASE=pg_multitenant_test bundle exec rspec --tag integration
```

## 🐳 Method 3: Docker-based Testing

Create a local testing environment that mirrors CI:

```bash
# Create Dockerfile.test
cat > Dockerfile.test << 'EOF'
FROM ruby:3.3

# Install PostgreSQL client
RUN apt-get update && apt-get install -y postgresql-client

# Set working directory
WORKDIR /app

# Copy Gemfile
COPY Gemfile* ./
RUN bundle install

# Copy source code
COPY . .

# Run tests
CMD ["bundle", "exec", "rspec"]
EOF

# Build and run
docker build -f Dockerfile.test -t pg_multitenant_test .
docker run --rm pg_multitenant_test
```

## 🔍 Method 4: GitHub CLI for Remote Testing

Use GitHub CLI to trigger workflows manually:

```bash
# Install GitHub CLI
brew install gh

# Authenticate
gh auth login

# Trigger workflow manually
gh workflow run main.yml

# Check workflow status
gh run list

# View workflow logs
gh run view --log
```

## 📋 Pre-Push Checklist

Before pushing to GitHub, run these commands locally:

```bash
#!/bin/bash
# pre-push-check.sh

echo "🔍 Running pre-push checks..."

# 1. RuboCop
echo "Running RuboCop..."
bundle exec rubocop || exit 1

# 2. RSpec
echo "Running RSpec..."
bundle exec rspec || exit 1

# 3. Security audit
echo "Running security audit..."
bundle audit || exit 1

# 4. Gem build test
echo "Testing gem build..."
gem build pg_multitenant_schemas.gemspec || exit 1

# 5. Integration tests (if PostgreSQL available)
if command -v psql &> /dev/null; then
    echo "Running integration tests..."
    bundle exec rspec --tag integration || exit 1
fi

echo "✅ All checks passed! Ready to push."
```

Make it executable:

```bash
chmod +x pre-push-check.sh
./pre-push-check.sh
```

## 🎯 Specific Workflow Testing

### Testing CI Workflow (main.yml)

```bash
# Using act
act push -W .github/workflows/main.yml

```bash
# Manual simulation
bundle install
bundle exec rubocop
bundle exec rspec --exclude-pattern '**/integration/**/*_spec.rb'
bundle audit
```
```

### Testing Release Workflow (release.yml)

```bash
# Simulate version bump
# 1. Update version in lib/pg_multitenant_schemas/version.rb
# 2. Test locally
act push -W .github/workflows/release.yml --env GITHUB_REF=refs/heads/main

# Manual simulation (without actual publishing)
gem build pg_multitenant_schemas.gemspec
# Note: Don't run 'gem push' in testing
```

## 🛠️ Troubleshooting

### Common Issues with `act`

1. **Docker not running**: Start Docker Desktop
2. **Permission issues**: Run with `sudo` or fix Docker permissions
3. **Platform issues**: Use `--container-architecture linux/amd64`
4. **Secret errors**: Provide secrets via `.env.local` file

### PostgreSQL Issues

```bash
# Check if PostgreSQL is running
pg_isready

# Start PostgreSQL service
brew services start postgresql@15

# Create test database
createdb pg_multitenant_test
```

### Ruby Version Issues

```bash
# Install required Ruby versions
rbenv install 3.2.0
rbenv install 3.3.0
rbenv install 3.4.0

# Test with specific version
rbenv shell 3.3.0
bundle install
bundle exec rspec
```

## 📚 Additional Resources

- [act Documentation](https://github.com/nektos/act)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Local Development Best Practices](https://docs.github.com/en/actions/using-workflows/about-workflows#best-practices)

## 🔗 Integration with Git Hooks

Add to `.git/hooks/pre-push`:

```bash
#!/bin/bash
./pre-push-check.sh
exit $?
```

This ensures checks run automatically before every push.
