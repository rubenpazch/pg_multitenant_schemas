# 🔧 Fixing GitHub Actions Permissions Issues

## 🚨 Problem
```
remote: Permission to rubenpazch/pg_multitenant_schemas.git denied to github-actions[bot].
fatal: unable to access 'https://github.com/rubenpazch/pg_multitenant_schemas/': The requested URL returned error: 403
```

## ✅ Solutions Applied

### 1. Updated Release Workflow Permissions
Added explicit permissions to `.github/workflows/release.yml`:
```yaml
permissions:
  contents: write
  issues: write
  pull-requests: write
```

### 2. Fixed GitHub Actions Bot Identity
Changed Git configuration to use proper GitHub Actions bot identity:
```yaml
git config --local user.email "41898282+github-actions[bot]@users.noreply.github.com"
git config --local user.name "github-actions[bot]"
```

## 🔧 Repository Settings to Check

### On GitHub.com:

1. **Go to your repository settings**
   - Navigate to: `https://github.com/rubenpazch/pg_multitenant_schemas/settings`

2. **Actions > General**
   - Scroll down to "Workflow permissions"
   - Select: **"Read and write permissions"**
   - Check: **"Allow GitHub Actions to create and approve pull requests"**
   - Click **Save**

3. **Actions > General > Actions permissions**
   - Ensure: **"Allow all actions and reusable workflows"** is selected
   - Or at least: **"Allow actions created by GitHub"**

## 🧪 Alternative Testing Approach

If you want to test the release workflow without actual releases:

### Create a Test Branch Release Workflow

```yaml
# .github/workflows/test-release.yml
name: Test Release Workflow

on:
  workflow_dispatch:  # Manual trigger only
  
permissions:
  contents: write
  issues: write
  pull-requests: write

jobs:
  test-release:
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0
          token: ${{ secrets.GITHUB_TOKEN }}
          
      - name: Test Git config
        run: |
          git config --local user.email "41898282+github-actions[bot]@users.noreply.github.com"
          git config --local user.name "github-actions[bot]"
          echo "Git config successful"
          
      - name: Test Git operations (dry run)
        run: |
          echo "Would create tag: v0.2.1"
          echo "Would push to origin"
          # Don't actually push in test
          
      - name: Test gem build
        run: |
          gem build pg_multitenant_schemas.gemspec
          ls -la *.gem
```

## 🔍 Troubleshooting Steps

### 1. Check Token Permissions
```bash
# In GitHub Actions, this should show the permissions
echo "GITHUB_TOKEN permissions:"
echo "Contents: ${{ github.token }}"
```

### 2. Verify Repository Access
```bash
# Test if the bot can access the repo
git ls-remote origin
```

### 3. Check Branch Protection Rules
- Go to Settings > Branches
- Check if `main` branch has protection rules that block force pushes
- Ensure "Restrict pushes that create files" is not enabled

## 🎯 Quick Fix Summary

1. **✅ Updated workflow permissions** (already done)
2. **✅ Fixed bot identity** (already done)
3. **🔧 Check repository settings** (manual step on GitHub.com)
4. **🧪 Test with manual trigger** (if needed)

## 📋 Manual Steps Required

1. Go to your repository on GitHub.com
2. Navigate to Settings > Actions > General
3. Set "Workflow permissions" to "Read and write permissions"
4. Enable "Allow GitHub Actions to create and approve pull requests"
5. Save the settings

After making these changes, the release workflow should work properly!

## 🚀 Testing the Fix

After updating repository settings, you can test by:

1. **Making a small version bump**
2. **Pushing to main branch**  
3. **Watching the Actions tab** for successful execution

Or create the test workflow above and trigger it manually first.
