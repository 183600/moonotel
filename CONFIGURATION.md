# Vibe Coding Configuration Guide

## Quick Start

This repository includes an automation system that continuously runs MoonBit tests and fixes issues using AI (iFlow).

### Step 1: Create Configuration File

Create a file at `~/.vibe_coding_repos.conf` with your repository list:

```bash
#!/usr/bin/env bash
# Vibe Coding Repository Configuration

REPO_LIST=(
  "RepoName|GiteeURL|GitHubURL|APIBaseURL|APIKey|ModelName|AuthType"
  # Add more repositories as needed
)
```

### Step 2: Configure Your Repositories

Each repository entry follows this format:

```
"Name|GiteeCloneURL|GitHubPushURL|BaseURL|APIKey|ModelName|AuthType"
```

**Example:**

```bash
REPO_LIST=(
  "myproject|https://user:pass@gitee.com/user/repo.git|https://user:token@github.com/user/repo.git|https://integrate.api.nvidia.com/v1|nvapi-XXX|moonshotai/kimi-k2-thinking|openai-compatible"
)
```

### Step 3: Run the Automation

```bash
cd /home/engine/project
nohup bash run_vibe_coding.sh > /tmp/vibe_coding_runner.log 2>&1 &
```

## Configuration Fields Explained

| Field | Description | Example |
|-------|-------------|---------|
| **Name** | Local directory name | `myproject` |
| **GiteeCloneURL** | Gitee repository URL with credentials | `https://user:pass@gitee.com/user/repo.git` |
| **GitHubPushURL** | GitHub repository URL with credentials | `https://user:token@github.com/user/repo.git` |
| **BaseURL** | AI API endpoint | `https://integrate.api.nvidia.com/v1` |
| **APIKey** | API authentication key | `nvapi-XXX...` |
| **ModelName** | AI model to use | `moonshotai/kimi-k2-thinking` |
| **AuthType** | Authentication method | `openai-compatible` |

## Supported AI Providers

### NVIDIA API

```
BaseURL: https://integrate.api.nvidia.com/v1
Model: moonshotai/kimi-k2-thinking
AuthType: openai-compatible
```

### Groq API

```
BaseURL: https://api.groq.com/openai/v1
Model: openai/gpt-oss-120b
AuthType: openai-compatible
```

### Other OpenAI-Compatible APIs

You can use any OpenAI-compatible API by specifying the appropriate base URL, API key, and model name.

## Security Best Practices

1. **Never commit `~/.vibe_coding_repos.conf`** - This file contains sensitive credentials
2. **Use access tokens** instead of passwords when possible
3. **Limit token permissions** to only what's needed (read/write repository access)
4. **Rotate credentials** periodically
5. **Use environment-specific credentials** (different keys for dev/prod)

## Example Configuration

Here's a complete example:

```bash
#!/usr/bin/env bash
# ~/.vibe_coding_repos.conf

REPO_LIST=(
  # Project 1: Using NVIDIA API
  "feather-web|https://gituser:gitpass@gitee.com/org/feather.git|https://ghuser:ghp_token123@github.com/org/feather.git|https://integrate.api.nvidia.com/v1|nvapi-ABC123XYZ|moonshotai/kimi-k2-thinking|openai-compatible"
  
  # Project 2: Using Groq API
  "moonotel|https://gituser:gitpass@gitee.com/org/moonotel.git|https://ghuser:ghp_token456@github.com/org/moonotel.git|https://api.groq.com/openai/v1|gsk_ABC123XYZ|openai/gpt-oss-120b|openai-compatible"
  
  # Add more projects as needed...
)
```

## Troubleshooting

### Configuration not loading
```bash
# Verify the file exists
ls -lah ~/.vibe_coding_repos.conf

# Test loading manually
bash -c 'source ~/.vibe_coding_repos.conf && echo "Loaded ${#REPO_LIST[@]} repos"'
```

### Permissions error
```bash
# Make the config file readable
chmod 600 ~/.vibe_coding_repos.conf
```

### Git authentication fails
- Verify credentials are correct in GiteeURL and GitHubURL
- Check if tokens have required permissions
- Try cloning manually to test credentials

## Advanced Configuration

### Using Environment Variables

Instead of hardcoding credentials, you can use environment variables:

```bash
#!/usr/bin/env bash
# ~/.vibe_coding_repos.conf

REPO_LIST=(
  "myproject|${GITEE_URL}|${GITHUB_URL}|${API_BASE_URL}|${API_KEY}|${MODEL_NAME}|openai-compatible"
)
```

Then set the environment variables before running:

```bash
export GITEE_URL="https://user:pass@gitee.com/user/repo.git"
export GITHUB_URL="https://user:token@github.com/user/repo.git"
export API_BASE_URL="https://api.example.com/v1"
export API_KEY="your-api-key"
export MODEL_NAME="model-name"

bash run_vibe_coding.sh
```

### Per-Repository Settings

You can specify different API settings for each repository:

```bash
REPO_LIST=(
  # Fast model for simple projects
  "simple-lib|||https://api.fast.com/v1|key1|fast-model|openai-compatible"
  
  # Advanced model for complex projects
  "complex-app|||https://api.advanced.com/v1|key2|advanced-model|openai-compatible"
)
```

Note: Empty fields (|||) will use global defaults from vibe_coding.sh

## Migration Guide

If you previously had credentials in `scripts/vibe_coding.sh`, migrate them:

1. Copy your REPO_LIST array from `scripts/vibe_coding.sh`
2. Create `~/.vibe_coding_repos.conf`
3. Paste and update the array
4. Verify it loads correctly
5. Remove old credentials from `scripts/vibe_coding.sh`

## Getting Help

For more information:
- Main documentation: `README_AUTOMATION.md`
- Status report: `SETUP_STATUS.md`
- Project plan: `PLAN.md`
