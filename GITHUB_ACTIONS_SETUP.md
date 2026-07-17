# GitHub Actions CI/CD Setup Guide

> 🚀 Automated deployment workflows for `pg_multitenant_schemas` gem

## Overview

This setup provides **fully automated CI/CD pipelines** for your Ruby gem with:

- ✅ **Automated Testing** - Run tests across Ruby 3.0-3.3 and PostgreSQL 12-15
- ✅ **Automatic Publishing** - Push to RubyGems on version bumps
- ✅ **GitHub Releases** - Auto-create release notes and tags
- ✅ **Documentation Hosting** - Deploy to GitHub Pages automatically
- ✅ **GitHub Packages** - Backup package registry
- ✅ **Security Scanning** - Dependency vulnerability checks

## Workflows Created

### 1. **test.yml** - Test Suite
**Triggers:** Push to main/develop, all Pull Requests

**What it does:**
- Runs RSpec tests on Ruby 3.0, 3.1, 3.2, 3.3
- Tests against PostgreSQL 12, 13, 14, 15 (all combinations)
- Runs syntax checks and YARD documentation generation
- Uploads coverage reports to Codecov
- Publishes test results as GitHub check

**Key features:**
- Matrix testing (4 Ruby versions × 4 PostgreSQL versions = 16 test runs)
- Automatic coverage report uploads
- Test result annotation on PRs
- RuboCop linting (optional)

**Status Checks:**
- Shows as ✅ in PR if all tests pass
- Blocks merge if tests fail (configurable)

---

### 2. **deploy.yml** - Auto-Deploy to RubyGems
**Triggers:** Push to main when `version.rb` changes

**What it does:**
1. Detects if version changed (`lib/pg_multitenant_schemas/version.rb`)
2. Builds the gem package
3. Publishes to **RubyGems.org** (production registry)
4. Publishes to **GitHub Packages** (backup)
5. Creates Git tag (e.g., `v0.3.0`)
6. Creates GitHub Release with changelog

**How it works:**
```
You update version.rb to 0.3.1
    ↓
Push to main
    ↓
GitHub Actions detects version change
    ↓
Runs all tests
    ↓
✅ Tests pass → Publishes to RubyGems
❌ Tests fail → Stops, notifies you
    ↓
Automatically creates release
```

**Important:** Only publishes if tests pass ✅

---

### 3. **pages.yml** - Deploy Docs to GitHub Pages
**Triggers:** Push to main when `docs/` changes

**What it does:**
- Copies `docs/index.html` to GitHub Pages
- Includes markdown documentation as reference
- Makes docs available at: `https://rubenpazch.github.io/pg_multitenant_schemas/`

**GitHub Pages Setup Required:**
1. Go to GitHub repo → Settings → Pages
2. Select "Deploy from a branch"
3. Branch: `gh-pages`
4. Folder: `/ (root)`
5. Save

---

### 4. **security.yml** - Security Scanning
**Triggers:** Every push to main, weekly schedule

**What it does:**
- Bundler audit (CVE vulnerability scanning)
- Dependency freshness checks
- Brakeman (Rails security scanner)
- Secret detection (prevents leaked API keys)

---

## Setup Instructions

### ✅ Step 1: Set Up RubyGems API Key

1. Go to https://rubygems.org → Sign in → Settings
2. Click "API Access" or "API Keys"
3. Create new API key (or use existing)
4. Copy the API key

5. In GitHub repo: Settings → Secrets and variables → Actions
6. Click "New repository secret"
7. Name: `RUBYGEMS_API_KEY`
8. Value: (paste API key from RubyGems)
9. Click "Add secret"

✅ **Secret is now encrypted and only used during deploy**

---

### ✅ Step 2: Enable GitHub Pages

1. Go to GitHub repo → Settings → Pages
2. Under "Build and deployment":
   - Source: Select "GitHub Actions"
   - (Workflows will deploy automatically)
3. Save

✅ **Pages will be available at:**
```
https://rubenpazch.github.io/pg_multitenant_schemas/
```

---

### ✅ Step 3: Configure Branch Protection (Optional)

Require tests to pass before merging:

1. Settings → Branches → Add rule
2. Branch name pattern: `main`
3. Check "Require status checks to pass before merging"
4. Check "Require branches to be up to date before merging"
5. Save

✅ **Now PRs must pass tests to merge**

---

## How to Use

### Publishing a New Version

1. **Update version:**
   ```bash
   # Edit lib/pg_multitenant_schemas/version.rb
   VERSION = "0.3.1"
   ```

2. **Update CHANGELOG.md:**
   ```markdown
   ## [0.3.1] - 2024-01-17
   ### Added
   - New feature X
   ### Fixed
   - Bug Y
   ```

3. **Push to main:**
   ```bash
   git add -A
   git commit -m "Bump version to 0.3.1"
   git push origin main
   ```

4. **GitHub Actions automatically:**
   - ✅ Runs all tests
   - ✅ Publishes to RubyGems
   - ✅ Creates GitHub Release
   - ✅ Deploys docs
   - ✅ Creates Git tag

✅ **Done! No manual publishing needed.**

---

### Monitoring Deployments

1. Go to repo → Actions
2. See all workflow runs
3. Click workflow to see details
4. Each step shows logs

**Example workflow run:**
```
✅ test (Ruby 3.3, PG 15)
✅ test (Ruby 3.2, PG 15)
✅ ... 14 more tests ...
✅ publish-rubygems
✅ create-release
✅ deploy-pages
```

---

### Troubleshooting

**Issue: Deploy workflow didn't run**
- Check: Was version.rb changed?
- Check: Are you pushing to `main` branch?
- Solution: Version change is only trigger

**Issue: RubyGems publish failed**
- Check: Is RUBYGEMS_API_KEY secret set?
- Check: Are tests passing?
- Solution: Check Actions → Deploy workflow logs

**Issue: Tests are failing**
- Check: Pull request shows failing tests
- Go to: Actions → Test workflow → Details
- Check logs for error

**Issue: GitHub Pages not showing**
- Check: Go to Settings → Pages
- Check: Is "GitHub Actions" selected as source?
- Check: Did pages workflow complete? (Actions tab)

---

## Secrets Reference

| Secret | Where to Get | Where to Configure |
|--------|-------------|-------------------|
| `RUBYGEMS_API_KEY` | https://rubygems.org → Settings → API Keys | Repo Settings → Secrets |
| `GITHUB_TOKEN` | Automatic (GitHub provides) | Auto-configured |

---

## Workflow Details

### Test Matrix
```
Ruby versions: 3.0, 3.1, 3.2, 3.3
PostgreSQL: 12, 13, 14, 15

Total: 4 × 4 = 16 parallel test runs
Average time: ~5 minutes
```

### Deploy Conditions
```
Trigger: Push to main with version.rb change
Tests pass? → YES → Build & publish
           → NO  → Stop (notify via email)

Publish to:
1. RubyGems.org (primary)
2. GitHub Packages (backup)
3. GitHub Release (docs)
4. GitHub Pages (HTML site)
```

---

## Best Practices

✅ **Always bump version in version.rb for new releases**
- Example: `VERSION = "0.3.1"`

✅ **Update CHANGELOG.md with changes**
- Used in GitHub Release notes

✅ **Write descriptive commit messages**
- Shows in deployment logs

✅ **Test locally before pushing**
- Run `bundle exec rspec` locally first

✅ **Review GitHub Pages URL**
- Update README.md to link to docs

---

## File Summary

```
.github/workflows/
├── test.yml          - Run tests (triggered by push/PR)
├── deploy.yml        - Publish gem (triggered by version change)
├── pages.yml         - Deploy docs (triggered by docs/ change)
└── security.yml      - Security checks (scheduled + push)
```

---

## Quick Reference

| Action | Result |
|--------|--------|
| Push to main | Tests run + Results shown in Actions |
| Change version.rb | Auto-publishes gem to RubyGems |
| Merge PR to main | Tests must pass (branch protection) |
| Update docs/ | Auto-deploys to GitHub Pages |
| Weekly schedule | Security scans run |

---

## Next Steps

1. ✅ Set RUBYGEMS_API_KEY secret
2. ✅ Enable GitHub Pages
3. ✅ (Optional) Set branch protection
4. ✅ Try pushing a change to main
5. ✅ Check Actions tab to see workflows run

**That's it! Your gem now auto-deploys.** 🚀
