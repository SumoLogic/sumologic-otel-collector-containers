# Rolling Back a Release

## Overview

The rollback system allows you to revert container images in a specific channel
(test, rc, or stable) to the previous version when a problematic release is
discovered. Rollbacks are performed by repointing semantic tags (like `latest`,
`latest-fips`, etc.) to the previous image digests and cleaning up the
workflow-specific tags (e.g. Git commit SHA, version, etc.) from the bad
release.

## How It Works

### Promotion Process

When container images are promoted from one channel to another, the following happens:

1. **Images are copied** from the source repository to the destination repository:
   - Source channels: `ci`, `rc`, or `test`
   - Destination channels: `rc`, `stable`, or `test`
   - Four image variants are promoted: base, fips, ubi, and ubi-fips

2. **Tags are created** for the promoted images:
   - Workflow-specific tags: `{workflow-id}`, `{workflow-id}-fips`, etc.
   - Git SHA tags: `{git-sha}`, `{git-sha}-fips`, etc.
   - Semantic tags: `latest`, `latest-fips`, `latest-ubi`, `latest-ubi-fips`

3. **Repositories involved**:
   - **Test channel**: Private ECR only (`663229565520.dkr.ecr.us-east-1.amazonaws.com/sumologic/sumologic-otel-collector-test`)
   - **RC channel**: Private ECR + Docker Hub (`663229565520.dkr.ecr.us-east-1.amazonaws.com/sumologic/sumologic-otel-collector-release-candidates` and `docker.io/sumologic/sumologic-otel-collector-release-candidates`)
   - **Stable channel**: Public ECR + Docker Hub (`public.ecr.aws/sumologic/sumologic-otel-collector` and `docker.io/sumologic/sumologic-otel-collector`)

### Rollback Process

When a rollback is triggered, the workflow:

1. **Identifies the current problematic images** using the workflow ID from the promotion that needs to be rolled back
2. **Finds the previous version** by scanning for the most recent workflow ID tag (numeric) that points to a different image digest
3. **Relinks semantic tags** (like `latest`, `latest-fips`, etc.) to point to the previous image digests
4. **Removes workflow-specific tags** associated with the problematic release (both workflow ID and git SHA tags)
5. **Operates on all variants** (base, fips, ubi, ubi-fips) and all applicable repositories (ECR and Docker Hub)

## Available Channels

- **test**: Internal channel for testing GitHub Actions, ECR only
- **rc**: Release candidate channel for pre-release testing, ECR + Docker Hub
- **stable**: Production stable releases, Public ECR + Docker Hub

## When to Rollback

Consider performing a rollback when:

- A critical bug is discovered in a recently promoted release
- Security vulnerabilities are found in the promoted images
- The promoted images fail in production or testing environments
- Incorrect images were promoted by mistake

## How to Perform a Rollback

### Prerequisites

Before performing a rollback:

1. **Identify the workflow ID** of the promotion that needs to be rolled back
   - Navigate to the Actions tab in GitHub
   - Find the promotion workflow run that deployed the problematic version
   - Note the workflow run ID (visible in the URL or run details)

2. **Verify the channel** you need to rollback (test, rc, or stable)

### Rollback Test Channel

1. **Navigate to the workflow:**
   - Go to https://github.com/SumoLogic/sumologic-otel-collector-containers/actions/workflows/rollback-test.yml
   - Click "Run workflow"

2. **Enter the Workflow Run ID:**
   - Input the Run ID of the promotion workflow that needs to be rolled back
     (e.g. `19034289856`)
   - Click "Run workflow"

3. **Monitor the workflow:**
   - Container indexes and images will be removed from the test channel
   - Tag aliases (e.g. `latest`) will point to the previous release

### Rollback Release Candidate Channel

1. **Navigate to the workflow:**
   - Go to https://github.com/SumoLogic/sumologic-otel-collector-containers/actions/workflows/rollback-release-candidate.yml
   - Click "Run workflow"

2. **Enter the Workflow Run ID:**
   - Input the Run ID of the promotion workflow that needs to be rolled back
     (e.g. `19034289856`)
   - Click "Run workflow"

3. **Monitor the workflow:**
   - Container indexes and images will be removed from the release-candidates
     channel
   - Tag aliases (e.g. `latest`) will point to the previous release

This will rollback images in both:
- Private ECR: `663229565520.dkr.ecr.us-east-1.amazonaws.com/sumologic/sumologic-otel-collector-release-candidates`
- Docker Hub: `docker.io/sumologic/sumologic-otel-collector-release-candidates`

### Rollback Stable Channel

1. **Navigate to the workflow:**
   - Go to https://github.com/SumoLogic/sumologic-otel-collector-containers/actions/workflows/rollback-stable.yml
   - Click "Run workflow"

2. **Enter the Workflow Run ID:**
   - Input the Run ID of the promotion workflow that needs to be rolled back
     (e.g. `19034289856`)
   - Click "Run workflow"

3. **Monitor the workflow:**
   - Container indexes and images will be removed from the stable
     channel
   - Tag aliases (e.g. `latest`) will point to the previous release

This will rollback images in both:
- Public ECR: `public.ecr.aws/sumologic/sumologic-otel-collector`
- Docker Hub: `docker.io/sumologic/sumologic-otel-collector`

## What Happens During Rollback

The rollback workflow (`.github/workflows/workflow-rollback.yml`) performs the following steps:

1. **Validates the channel** - Ensures the channel is one of: test, rc, or stable

2. **Authenticates to registries**:
   - Private ECR (all channels)
   - Public ECR (stable only)
   - Docker Hub (rc and stable only)

3. **Retrieves workflow metadata** - Fetches the git SHA associated with the problematic workflow run

4. **Determines tags to remove**:
   - Workflow ID tags: `{workflow-id}`, `{workflow-id}-fips`, `{workflow-id}-ubi`, `{workflow-id}-ubi-fips`
   - Git SHA tags: `{git-sha}`, `{git-sha}-fips`, `{git-sha}-ubi`, `{git-sha}-ubi-fips`

5. **Finds previous image digests** for each variant:
   - Lists all tags in the repository
   - Identifies the current image digest from the problematic workflow ID
   - Searches for the most recent previous workflow ID tag with a different digest
   - Repeats for all four variants (base, fips, ubi, ubi-fips)

6. **Relinks semantic tags** to the previous digests:
   - `latest` → previous base image
   - `latest-fips` → previous fips image
   - `latest-ubi` → previous ubi image
   - `latest-ubi-fips` → previous ubi-fips image

7. **Removes workflow-specific tags** from both ECR and Docker Hub (if applicable)

## Verification

After a rollback completes:

1. **Check the workflow logs** to ensure all steps completed successfully
2. **Verify the semantic tags** point to the correct previous version:
   ```bash
   crane digest <repository>:latest
   ```
3. **Test the rolled-back images** in your environment to confirm they work as expected

## Marking GitHub Release as Deprecated

When rolling back a stable release, you should also deprecate the corresponding GitHub Release to warn users not to use the problematic version.

### Convert Release to Pre-Release

1. Navigate to the **Releases** page in the GitHub repository
2. Find the release that corresponds to the rolled-back version
3. Click **Edit** on the release
4. Check the **"Set as a pre-release"** checkbox
5. Click **"Update release"**

This will mark the release with a "Pre-release" badge, signaling to users that it should not be used in production.

### Add Deprecation Warning

Update the release notes to include a clear deprecation warning at the top:

1. Edit the release notes
2. Add a warning section at the beginning explaining why the release was deprecated
3. Provide links to relevant issues or pull requests if applicable

Example deprecation notice:

```markdown
> **WARNING: This release has been deprecated**
>
> This release has been **deprecated** due to [brief description of the issue].
> Please use the previous stable release or wait for the next release.
>
> For more information, see [link to issue/PR].
```

**Real example** from [v0.133.0-2274](https://github.com/SumoLogic/sumologic-otel-collector-packaging/releases/tag/v0.133.0-2274):

```markdown
> This release has been **deprecated** due to upstream issues with the
> `gosnowflake` dependency, which required a downgrade as mentioned in
> open-telemetry/opentelemetry-collector-contrib#42607.
```
