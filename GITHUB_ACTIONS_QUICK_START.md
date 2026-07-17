# GitHub Actions Quick Start ⚡

## One-Time Setup (5 minutes)

### 1️⃣ Add RubyGems API Key
```bash
# Go to: GitHub repo → Settings → Secrets and variables → Actions
# Click: New repository secret
# Name: RUBYGEMS_API_KEY
# Value: (paste from https://rubygems.org → Settings → API Keys)
```

### 2️⃣ Enable GitHub Pages
```bash
# Go to: GitHub repo → Settings → Pages
# Source: GitHub Actions
# Save
```

### 3️⃣ Push Workflows
```bash
cd /Users/rubenpaz/personal/frontend/pg_multitenant_schemas
git add .github/
git commit -m "Add GitHub Actions CI/CD workflows"
git push origin main
```

---

## From Now On...

### 📦 Publish New Version
```bash
# 1. Update version
vim lib/pg_multitenant_schemas/version.rb
# Change: VERSION = "0.3.1"

# 2. Update changelog
vim CHANGELOG.md
# Add release notes

# 3. Push to main
git add -A
git commit -m "Bump version to 0.3.1"
git push origin main

# ✅ GitHub Actions will automatically:
#    - Run 16 test combinations
#    - Publish to RubyGems
#    - Create GitHub Release
#    - Deploy docs to GitHub Pages
```

---

## 🔍 Monitor Deployments

```bash
# Open in browser:
# https://github.com/rubenpazch/pg_multitenant_schemas/actions

# You'll see:
# ✅ test.yml - Running...
# ✅ deploy.yml - Waiting for tests...
# ✅ pages.yml - Deployed!
```

---

## 📊 Workflows Overview

| Workflow | Trigger | Action |
|----------|---------|--------|
| **test.yml** | Push to main / PR | Run 16 test combinations |
| **deploy.yml** | Version change | Publish to RubyGems |
| **pages.yml** | Docs/ change | Deploy to GitHub Pages |
| **security.yml** | Weekly + push | Security scans |

---

## 🔑 Secrets Configured

- ✅ `RUBYGEMS_API_KEY` - Added manually (see step 1)
- ✅ `GITHUB_TOKEN` - Auto by GitHub

---

## ⚠️ Important Notes

- Tests must pass to deploy
- Only changes to `version.rb` trigger deploy
- GitHub Pages URL: `https://rubenpazch.github.io/pg_multitenant_schemas/`
- Releases auto-created with CHANGELOG content

---

## 🆘 Troubleshooting

**No deploy after push?**
- Check: Did you change `version.rb`?
- Check: Are tests passing?

**RubyGems publish failed?**
- Check: RUBYGEMS_API_KEY secret is set?

**Pages not showing?**
- Check: Pages source is "GitHub Actions"?

**Need details?**
- See: `GITHUB_ACTIONS_SETUP.md` (full guide)
