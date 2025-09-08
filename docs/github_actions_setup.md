# GitHub Actions Setup Guide

This document explains how to set up GitHub Actions for automated testing and releases.

## Overview

The repository uses two main workflows:

1. **CI Workflow** (`.github/workflows/main.yml`) - Runs tests on every push and PR
2. **Release Workflow** (`.github/workflows/release.yml`) - Automatically releases to RubyGems when version changes

## Setting Up RubyGems API Key

To enable automatic releases to RubyGems, you need to set up a GitHub secret with your RubyGems API key.

### Step 1: Get Your RubyGems API Key

1. Go to [RubyGems.org](https://rubygems.org/)
2. Sign in to your account
3. Go to your profile settings
4. Navigate to "API Keys" section
5. Create a new API key or use an existing one
6. Copy the API key (it should start with `rubygems_`)

### Step 2: Add GitHub Secret

1. Go to your GitHub repository
2. Click on "Settings" tab
3. In the left sidebar, click "Secrets and variables" → "Actions"
4. Click "New repository secret"
5. Name: `RUBYGEMS_API_KEY`
6. Value: Paste your RubyGems API key
7. Click "Add secret"

### 3. Configure Repository Permissions

**Important:** Configure GitHub Actions permissions to allow the release workflow to create tags and releases:

1. Go to your repository Settings
2. Navigate to **Actions > General**
3. Under "Workflow permissions":
   - Select **"Read and write permissions"**
   - Check **"Allow GitHub Actions to create and approve pull requests"**
4. Click **Save**

Without these permissions, you'll get errors like:
```
remote: Permission to username/repo.git denied to github-actions[bot].
fatal: unable to access 'https://github.com/username/repo/': The requested URL returned error: 403
```

## How the Workflows Work

### CI Workflow

**Triggers:**
- Every push to `main` branch
- Every pull request to `main` branch

**What it does:**
- Tests on Ruby 3.2, 3.3, and 3.4
- Runs RuboCop for code quality
- Runs unit tests (excluding integration tests)
- Runs integration tests (with PostgreSQL database)
- Runs security audit with bundle-audit

### Release Workflow

**Triggers:**
- Push to `main` branch that changes `lib/pg_multitenant_schemas/version.rb`

**What it does:**
- Checks if the version in `version.rb` has changed
- If version changed:
  1. Builds the gem
  2. Creates a Git tag (e.g., `v0.2.1`)
  3. Creates a GitHub release with changelog notes
  4. Publishes the gem to RubyGems

## Release Process

To release a new version:

1. **Update the version** in `lib/pg_multitenant_schemas/version.rb`:
   ```ruby
   module PgMultitenantSchemas
     VERSION = "0.2.1"  # Increment this
   end
   ```

2. **Update the changelog** in `CHANGELOG.md`:
   ```markdown
   ## [0.2.1] - 2025-09-07
   
   ### Added
   - New feature description
   
   ### Fixed
   - Bug fix description
   ```

3. **Commit and push** to main branch:
   ```bash
   git add lib/pg_multitenant_schemas/version.rb CHANGELOG.md
   git commit -m "Bump version to 0.2.1"
   git push origin main
   ```

4. **Automatic release** will trigger:
   - GitHub Actions will detect the version change
   - Create a Git tag and GitHub release
   - Publish to RubyGems automatically

## Manual Release (Alternative)

If you prefer manual releases or need to troubleshoot:

```bash
# Build the gem
gem build pg_multitenant_schemas.gemspec

# Push to RubyGems (requires authentication)
gem push pg_multitenant_schemas-0.2.1.gem

# Create Git tag
git tag v0.2.1
git push origin v0.2.1
```

## Workflow Status

You can monitor workflow runs:

1. Go to your GitHub repository
2. Click the "Actions" tab
3. View running and completed workflows
4. Click on individual runs to see detailed logs

## Security Considerations

- **API Keys**: Never commit API keys to the repository
- **Secrets**: Use GitHub Secrets for sensitive information
- **Permissions**: The `GITHUB_TOKEN` has limited permissions for creating releases
- **Audit**: The security workflow checks for vulnerable dependencies

## Troubleshooting

### Common Issues

1. **RubyGems authentication failed**
   - Check that `RUBYGEMS_API_KEY` secret is set correctly
   - Ensure the API key has publishing permissions

2. **Git tag already exists**
   - The workflow checks for existing tags
   - If tag exists, release is skipped

3. **Tests failing**
   - CI must pass before release workflow runs
   - Check test logs in the Actions tab

4. **PostgreSQL connection issues**
   - Integration tests require PostgreSQL service
   - Check service configuration in workflow

### Debug Steps

1. Check workflow logs in GitHub Actions
2. Verify secrets are set correctly
3. Test locally with same Ruby versions
4. Check RubyGems.org for published gems

## Best Practices

1. **Version Bumping**: Use semantic versioning (MAJOR.MINOR.PATCH)
2. **Changelog**: Always update changelog before releasing
3. **Testing**: Ensure all tests pass locally before pushing
4. **Security**: Regularly update dependencies and run security audits
5. **Documentation**: Update documentation for breaking changes

This automated setup ensures consistent, reliable releases while maintaining code quality through comprehensive testing.
