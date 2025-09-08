# 🚀 Quick Start: Testing GitHub Workflows Locally

This guide gets you up and running quickly with local GitHub Actions testing.

## 🎯 TL;DR - Quick Commands

```bash
# 1. Run pre-push checks (recommended before every push)
./pre-push-check.sh

# 2. Test GitHub Actions locally with act
act -l                    # List all workflows
act push                  # Test CI workflow
act pull_request         # Test PR workflow

# 3. Manual component testing
bundle exec rubocop      # Code style check
bundle exec rspec        # Run tests
gem build *.gemspec     # Test gem building
```

## 🔧 One-Time Setup

### 1. Install act (if not already installed)

```bash
# macOS
brew install act

# Linux
curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash

# Windows
choco install act-cli
```

### 2. Create local environment file

```bash
# Copy the example and fill in your values
cp .env.local.example .env.local

# Edit with your actual tokens (optional, only needed for release testing)
nano .env.local
```

## 🧪 Testing Strategies

### Strategy 1: Pre-Push Script (Recommended)

Run this before every push:

```bash
./pre-push-check.sh
```

This runs:
- ✅ RuboCop (code style)
- ✅ RSpec (unit tests)  
- ✅ Security audit
- ✅ Gem build test
- ✅ Integration tests (if PostgreSQL available)

### Strategy 2: act - GitHub Actions Locally

```bash
# Test the main CI workflow
act push

# Test pull request workflow
act pull_request

# Dry run (see what would execute)
act -n

# Test specific job
act -j test

# List all available workflows and jobs
act -l
```

### Strategy 3: Manual Component Testing

```bash
# Test each component individually
bundle install
bundle exec rubocop
bundle exec rspec
bundle exec rspec --exclude-pattern '**/integration/**/*_spec.rb'  # Unit tests only
bundle exec rspec --tag integration  # Integration tests only
bundle audit
gem build pg_multitenant_schemas.gemspec
```

## 🎯 Workflow-Specific Testing

### Testing CI Workflow (.github/workflows/main.yml)

```bash
# With act
act push

# Manual simulation
bundle install
bundle exec rubocop
bundle exec rspec --exclude-pattern '**/integration/**/*_spec.rb'
bundle audit
```

### Testing Release Workflow (.github/workflows/release.yml)

```bash
# With act (simulates main branch push)
act push --env GITHUB_REF=refs/heads/main

# Manual simulation (WITHOUT publishing)
# 1. Update version in lib/pg_multitenant_schemas/version.rb
# 2. Build gem locally
gem build pg_multitenant_schemas.gemspec
# 3. Check gem contents
gem contents pg_multitenant_schemas-*.gem
```

## 🐛 Troubleshooting

### act Issues

```bash
# Docker not running
# → Start Docker Desktop

# Permission denied
# → Fix Docker permissions or use sudo

# Platform issues
act --container-architecture linux/amd64

# Secrets not found
# → Check .env.local file exists and has correct values
```

### PostgreSQL Issues

```bash
# Check if PostgreSQL is running
pg_isready

# Start PostgreSQL (macOS)
brew services start postgresql@15

# Create test database
createdb pg_multitenant_test
```

### Ruby/Bundle Issues

```bash
# Install correct Ruby version
rbenv install 3.3.0
rbenv local 3.3.0

# Clean and reinstall gems
bundle clean --force
bundle install
```

## 🔄 Typical Workflow

1. **Make changes** to your code
2. **Run pre-push checks**: `./pre-push-check.sh`
3. **Fix any issues** found
4. **Test with act** (optional): `act push`
5. **Commit and push** when everything passes

## 📋 Integration with Git

Add to `.git/hooks/pre-push` to run checks automatically:

```bash
#!/bin/bash
./pre-push-check.sh
```

Make it executable:
```bash
chmod +x .git/hooks/pre-push
```

## 🎉 Success Indicators

You're ready to push when you see:

- ✅ Pre-push script passes all checks
- ✅ `act push` completes without errors
- ✅ All tests pass locally
- ✅ RuboCop shows no violations
- ✅ Gem builds successfully

## 🔗 More Information

- [Complete Guide](docs/local_workflow_testing.md) - Detailed documentation
- [GitHub Actions Docs](https://docs.github.com/en/actions)
- [act Documentation](https://github.com/nektos/act)

---

**💡 Pro Tip**: Run `./pre-push-check.sh` before every commit to catch issues early!
