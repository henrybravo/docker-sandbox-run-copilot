---
on:
  schedule: daily on weekdays
  workflow_dispatch:
  skip-if-match: "is:pr is:open label:version-update"
name: Check Copilot CLI Version
description: Check for new GitHub Copilot CLI releases and create a PR to update version references in this repository
permissions:
  contents: read
  issues: read
  pull-requests: read
tools:
  github:
    mode: remote
    toolsets: [default]
  edit:
  bash: true
safe-outputs:
  create-pull-request:
    labels: [version-update, automated]
    draft: false
    if-no-changes: ignore
---

# Check Copilot CLI Version and Update

Your task is to check if there is a newer version of the GitHub Copilot CLI available. If a newer version exists, update the version references in this repository and create a pull request.

## Instructions

### Step 1: Get the Latest Copilot CLI Release

Use the GitHub tools to get the **latest release** from the `github/copilot-cli` repository. Look for the most recent release tag (e.g., `v1.0.5`). Extract the version number by stripping the leading `v` prefix (e.g., `1.0.5`).

### Step 2: Read the Current Version

Read the current tracked version from the `.copilot-version` file using bash:

```bash
cat .copilot-version
```

This file contains only the version number (e.g., `1.0.4`), without a `v` prefix.

### Step 3: Compare Versions

Compare the latest release version with the current version using semantic versioning rules (major.minor.patch). If the latest version is **greater than** the current version, proceed to Step 4. Otherwise, print "Copilot CLI is already at the latest version (X.X.X). No update needed." and stop — do **not** create a pull request.

### Step 4: Update the Version Files

If a newer version is available, update the following two files:

1. **`.copilot-version`** — Replace the entire content with the new version number followed by a newline (e.g., `1.0.5\n`). No `v` prefix.

2. **`README.md`** — Find the line containing `img.shields.io/badge/Copilot_CLI-` and update the version number in the badge URL. The line looks like:
   ```
   [![Copilot CLI](https://img.shields.io/badge/Copilot_CLI-{CURRENT_VERSION}-blue?logo=githubcopilot&logoColor=white)](https://github.com/github/copilot-cli)
   ```
   Replace the old version number (e.g., `1.0.4`) with the new version number (e.g., `1.0.5`).

### Step 5: Create a Pull Request

After updating the files, create a pull request with these changes. Use the following format:

- **Title**: `chore: bump Copilot CLI to v{NEW_VERSION}`
- **Body**:
  ```
  ## Version Update: Copilot CLI v{NEW_VERSION}

  This PR updates the tracked GitHub Copilot CLI version from `v{CURRENT_VERSION}` to `v{NEW_VERSION}`.

  ### Changes
  - `.copilot-version`: Updated from `{CURRENT_VERSION}` to `{NEW_VERSION}`
  - `README.md`: Updated badge version from `{CURRENT_VERSION}` to `{NEW_VERSION}`

  ### Upstream Release
  See the upstream release notes at: https://github.com/github/copilot-cli/releases/tag/v{NEW_VERSION}

  When this PR is merged, a new GitHub release and tag `v{NEW_VERSION}` will be created automatically, which will trigger a new Docker image build and publish.
  ```
