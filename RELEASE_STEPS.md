# Release Steps for v0.3.0

Follow these steps to complete the release of pg_multitenant_schemas v0.3.0:

## Step 1: Verify Everything is Ready

```bash
cd /Users/rubenpaz/personal/frontend/pg_multitenant_schemas

# Check git status
git status

# Run tests one more time
bundle exec rspec --format=progress

# Check version
grep "VERSION = " lib/pg_multitenant_schemas/version.rb
```

**Expected Output:**
- All tests passing (217 examples, 0 failures)
- Version: 0.3.0
- All changes committed

## Step 2: Push to GitHub

```bash
# Push commits
git push origin main

# Push tags
git push origin v0.3.0

# Verify on GitHub
# https://github.com/rubenpazch/pg_multitenant_schemas
```

## Step 3: Build and Push Gem to RubyGems

```bash
# Build the gem
gem build pg_multitenant_schemas.gemspec

# This should create: pg_multitenant_schemas-0.3.0.gem

# Push to RubyGems
gem push pg_multitenant_schemas-0.3.0.gem

# You'll be prompted for your RubyGems API key
```

## Step 4: Verify Release

```bash
# Check RubyGems
# https://rubygems.org/gems/pg_multitenant_schemas

# Should see v0.3.0 as latest version
# Downloads counter updated
# Documentation link available
```

## Step 5: Create GitHub Release

1. Go to: https://github.com/rubenpazch/pg_multitenant_schemas/releases
2. Click "Draft a new release"
3. Tag: v0.3.0
4. Title: "v0.3.0 - Production-ready with YARD docs and HTML site"
5. Description: Copy content from RELEASE_NOTES.md
6. Click "Publish release"

## Step 6: Update README (Optional)

If you want, update the main README.md to mention:
- v0.3.0 now available
- Link to HTML documentation site
- Link to YARD documentation on RubyDoc

## Verification Checklist

- [ ] Git commits pushed
- [ ] Tags pushed
- [ ] Gem built successfully
- [ ] Gem uploaded to RubyGems
- [ ] RubyGems shows v0.3.0
- [ ] GitHub release created
- [ ] Documentation site accessible
- [ ] No errors or warnings

## Rollback (if needed)

If something goes wrong:

```bash
# Delete tag locally
git tag -d v0.3.0

# Delete tag on GitHub
git push origin :v0.3.0

# Revert commit
git reset --hard HEAD~1
git push origin main -f

# Delete gem from RubyGems (requires RubyGems access)
gem yank pg_multitenant_schemas -v 0.3.0
```

## Post-Release

After successful release:

1. Celebrate! 🎉
2. Monitor for any issues
3. Plan v0.4.0 features
4. Thank community contributors
5. Update documentation as needed

---

**Release Date:** July 17, 2025  
**Status:** ✅ Ready to Release
