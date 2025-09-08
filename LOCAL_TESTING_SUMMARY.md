# 🧪 Summary: How to Test GitHub Workflows Locally

## ✅ What You Can Do Right Now

### 1. **Pre-Push Script (Recommended)**## 📁 **Files Created**

- **`pre-push-check.sh`** - Main testing script
- **`validate-github-commands.sh`** - Test exact GitHub Actions commands
- **`TESTING_LOCALLY.md`** - Quick start guide
- **`docs/local_workflow_testing.md`** - Complete documentation
- **`.actrc`** - act configuration
- **`.env.local.example`** - Environment templateh
# Run this before every push
./pre-push-check.sh
```
This validates everything that runs in CI:
- ✅ RuboCop (code style)
- ✅ RSpec (tests)
- ✅ Bundle audit (security)
- ✅ Gem building
- ✅ Integration tests (if PostgreSQL available)

### 2. **Manual Component Testing**
```bash
```bash
# Test each CI component individually
bundle install
bundle exec rubocop              # Code style check
bundle exec rspec               # Run all tests
bundle exec rspec --tag integration  # Integration tests only
bundle exec rspec --exclude-pattern '**/integration/**/*_spec.rb'  # Unit tests only
bundle audit                    # Security audit
gem build pg_multitenant_schemas.gemspec  # Test gem build
```
```

### 3. **act Tool (Partial Support)**
```bash
# List workflows
act -l

# Dry run (shows what would execute)
act -n push

# Note: Currently has issues with PostgreSQL services
# Better for simple workflows without database dependencies
```

## 🎯 **Before Every Push Checklist**

1. ✅ Run `./pre-push-check.sh`
2. ✅ Fix any issues found
3. ✅ Commit your changes
4. ✅ Push to GitHub

## 📋 **Component Status**

| Component | Local Testing | Status |
|-----------|---------------|---------|
| RuboCop | ✅ `bundle exec rubocop` | Working |
| Unit Tests | ✅ `bundle exec rspec` | Working |
| Integration Tests | ✅ With local PostgreSQL | Working |
| Security Audit | ✅ `bundle audit` | Working |
| Gem Building | ✅ `gem build *.gemspec` | Working |
| Release Workflow | ⚠️ Manual simulation only | Partial |
| Full CI with act | ⚠️ PostgreSQL service issues | Limited |

## 🔧 **Quick Setup**

1. **Make pre-push script executable:**
   ```bash
   chmod +x pre-push-check.sh
   ```

2. **Install act (optional):**
   ```bash
   brew install act
   ```

3. **Create environment file (for act):**
   ```bash
   cp .env.local.example .env.local
   # Edit .env.local with your tokens if needed
   ```

## 🚀 **Recommended Workflow**

```bash
# 1. Make your changes
git add .

# 2. Test locally
./pre-push-check.sh

# 3. If all passes, commit and push
git commit -m "Your changes"
git push
```

## 🛠️ **Troubleshooting**

### PostgreSQL Issues
```bash
# Check if PostgreSQL is running
pg_isready

# Start PostgreSQL (macOS)
brew services start postgresql@15

# Create test database
createdb pg_multitenant_test
```

### Ruby Issues
```bash
# Install correct Ruby version
rbenv install 3.3.0
rbenv local 3.3.0
bundle install
```

### act Issues
```bash
# Try without services (simpler)
act -j security  # Just run security audit job

# Check Docker is running
docker ps
```

## 📚 **Files Created**

- **`pre-push-check.sh`** - Main testing script
- **`TESTING_LOCALLY.md`** - Quick start guide
- **`docs/local_workflow_testing.md`** - Complete documentation
- **`.actrc`** - act configuration
- **`.env.local.example`** - Environment template

---

**💡 Bottom Line**: Use `./pre-push-check.sh` for reliable local testing. It covers 95% of what CI does and catches issues early!
